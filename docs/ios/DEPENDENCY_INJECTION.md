# Dependency Injection

**Purpose:** Documenta como o Jordania gerencia dependências — como o grafo é construído, como tipos recebem suas dependências e as regras que mantêm tudo explícito e testável.

**Scope:** Composition root, padrões de injeção e regras. O motivo dessas escolhas está em [ADR-003](../architecture/DECISION_LOG.md). As camadas de arquitetura estão descritas em [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md).

---

## Table of Contents

1. [Princípios](#princípios)
2. [AppContainer — A Composition Root](#appcontainer--a-composition-root)
3. [Grafo de Dependências](#grafo-de-dependências)
4. [Padrões de Injeção](#padrões-de-injeção)
5. [Regras de Dependência](#regras-de-dependência)
6. [Testes sem Protocolos](#testes-sem-protocolos)

---

## Princípios

1. **Inicializadores são o único mecanismo de injeção.** Tipos declaram suas dependências como parâmetros de `init`. Sem property injection, sem setter injection, sem globals ambiente.
2. **Uma única composition root.** `AppContainer` é instanciado uma vez por `JordaniaTeamApp` e é o único lugar onde o grafo de dependências é montado.
3. **Sem framework.** Swinject, Needle, Factory e equivalentes não são usados. Swift puro é suficiente para o tamanho do projeto.
4. **Sem Service Locator.** Tipos não buscam suas dependências em um registro global. Recebem exatamente o que precisam no `init` — nada mais.
5. **SwiftUI environment apenas para `SessionStore`.** `SessionStore` é propagado via `.environment()` para ser acessível em profundidade na árvore de Views sem ser passado por cada View intermediária. Essa é a exceção, não o modelo.

---

## AppContainer — A Composition Root

`AppContainer` constrói o grafo completo em seu `init`. A ordem de construção é determinada pelas relações de dependência:

```swift
// AppContainer.swift
@MainActor
final class AppContainer {

    let sessionStore: SessionStore
    let apiClient: APIClient
    let authViewModel: AuthViewModel
    let userService: UserService

    init(
        persistence: SessionPersistence = SessionPersistence(),
        authService: BackendAuthService = BackendAuthService(),
        urlSession: URLSession = .shared
    ) {
        let store = SessionStore(persistence: persistence)
        let tokenProvider = TokenProvider(
            persistence: persistence,
            authService: authService,
            sessionStore: store
        )
        let client = APIClient(
            tokenProvider: tokenProvider,
            session: urlSession,
            sessionStore: store
        )

        self.sessionStore  = store
        self.apiClient     = client
        self.authViewModel = AuthViewModel(session: store)
        self.userService   = UserService(apiClient: client)
    }

    func bootstrap() {
        configureGoogleSignIn()
    }
}
```

O `init` aceita overrides para `SessionPersistence`, `BackendAuthService` e `URLSession` — os três pontos que precisam ser substituídos em testes ou configurações alternativas. Todos os outros tipos são construídos a partir desses três.

`bootstrap()` é chamado explicitamente por `JordaniaTeamApp.body` via `.task { container.bootstrap() }`. Essa separação mantém o `init` puro e livre de side effects.

### Entry point

```swift
// JordaniaTeamApp.swift
@main
struct JordaniaTeamApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .task {
                    container.bootstrap()
                    await container.sessionStore.validateSession(using: container.userService)
                }
        }
    }
}
```

`AppContainer` é criado como propriedade armazenada de `JordaniaTeamApp` — instanciado uma única vez, no launch, antes do primeiro render.

---

## Grafo de Dependências

```
SessionPersistence
  └── SessionStore
        └── AuthViewModel

SessionPersistence + BackendAuthService + SessionStore
  └── TokenProvider
        └── APIClient
              └── UserService
```

Observações importantes sobre o grafo:

- `TokenProvider` e `APIClient` são `actor` — serializam acesso a estado compartilhado entre Tasks concorrentes.
- `APIClient` e `TokenProvider` mantêm `weak var sessionStore: SessionStore?` para evitar retain cycle no grafo.
- `SessionStore` não conhece `APIClient` — o flow de invalidação de sessão vai de `APIClient → TokenProvider → SessionStore.signOut()`, nunca o contrário.
- `AuthViewModel` recebe apenas `SessionStore` — não precisa de `APIClient` porque não faz chamadas de rede diretamente.

---

## Padrões de Injeção

### Padrão 1 — Init direto do ViewModel (padrão)

O padrão mais comum. `AppContainer` passa uma dependência para um ViewModel no momento da construção:

```swift
// AppContainer.init
self.authViewModel = AuthViewModel(session: store)
```

O ViewModel armazena a dependência como `private let`:

```swift
final class AuthViewModel {
    private let session: SessionStore
    private let appleAuthService: AppleAuthService
    private let googleAuthService: GoogleAuthService

    init(
        session: SessionStore,
        appleAuthService: AppleAuthService? = nil,
        googleAuthService: GoogleAuthService? = nil
    ) {
        self.session = session
        self.appleAuthService = appleAuthService ?? AppleAuthService()
        self.googleAuthService = googleAuthService ?? GoogleAuthService()
    }
}
```

Parâmetros opcionais com defaults são usados para services que não têm dependências externas e são facilmente substituídos em testes.

### Padrão 2 — ViewModel criado pela View no `init` (quando a View precisa de valores injetados)

Quando uma View precisa construir seu ViewModel com valores do call site, o ViewModel é criado dentro do `init` da View e possuído via `@State`:

```swift
// AuthView.swift
struct AuthView: View {
    @State private var viewModel: AuthViewModel

    init(session: SessionStore) {
        _viewModel = State(initialValue: AuthViewModel(session: session))
    }
}
```

Isso garante que o ViewModel é criado uma única vez, com as dependências corretas, antes do primeiro render da View.

### Padrão 3 — SwiftUI environment (apenas SessionStore)

`SessionStore` é injetado no environment SwiftUI em `RootView` para que Views profundas na subárvore de `AuthView` possam acessá-lo sem que cada View intermediária precise passá-lo:

```swift
// RootView.swift
case .signedOut:
    AuthView(session: container.sessionStore)
        .environment(container.sessionStore)
```

Views filhas lêem com `@Environment(SessionStore.self)`. Esse padrão é **reservado para `SessionStore` apenas**. Nunca use para services, ViewModels ou `AppContainer`.

### Padrão 4 — Propagação do container (para árvores de features)

Quando uma árvore de Views de feature precisa de múltiplas dependências do `AppContainer`, o container é passado explicitamente para a raiz da árvore:

```swift
// RootView.swift
case .authenticated:
    MainTabView(container: container)
```

`MainTabView` recebe `container` e passa services individuais para as Views de feature que precisam deles. Nenhuma View de feature importa ou armazena o `AppContainer` completo.

---

## Regras de Dependência

- **`AppContainer` é referenciado apenas em `App/`.** `RootView` e `MainTabView` o recebem; nenhum ViewModel ou service de feature referencia `AppContainer` diretamente.
- **Services são propriedades `private let` de seus consumidores.** Dependências são armazenadas, não buscadas.
- **Sem dependências opcionais além da fronteira `init` do `AppContainer`.** Internamente, todas as dependências são não-opcionais.
- **`weak var` para referências de volta que criariam retain cycle.** `APIClient` e `TokenProvider` mantêm `weak var sessionStore: SessionStore?` para evitar um cycle pelo grafo.
- **Sem singletons.** Nenhum tipo usa `static let shared` como ponto de acesso global. A única instância de cada service vive dentro de `AppContainer`.
- **`bootstrap()` para side effects de inicialização.** Configuração de SDKs de terceiros (Google Sign-In) fica em `bootstrap()`, não em `init`, mantendo `init` puro.

---

## Testes sem Protocolos

O projeto não adiciona protocolos para cada service (seriam abstrações prematuras para o tamanho atual). Testes substituem dependências via:

1. **Overrides do `init` do `AppContainer`** — passe um `URLSession` customizado (ex: um backed por `URLProtocol`) para interceptar chamadas de rede:

```swift
let mockSession = URLSession(configuration: mockConfiguration)
let container = AppContainer(urlSession: mockSession)
```

2. **Parâmetros opcionais do `init` do ViewModel** — `AuthViewModel` aceita `AppleAuthService?` e `GoogleAuthService?` opcionais, permitindo subclasses leves ou inicializações alternativas em testes.

3. **Observação de estado `@Observable`** — teste que `SessionStore.state` transita corretamente chamando `signIn` / `signOut` diretamente, sem precisar mockar o Keychain:

```swift
let store = SessionStore(persistence: inMemoryPersistence)
store.signIn(user: mockUser, accessToken: "token", refreshToken: "refresh")
#expect(store.state == .authenticated)
```

4. **Override de `SessionPersistence`** — passe uma `SessionPersistence` configurada com um `KeychainService` que armazena em memória durante testes, sem tocar no Keychain do sistema.
