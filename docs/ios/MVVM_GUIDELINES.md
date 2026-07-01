# MVVM Guidelines

**Purpose:** Define o que significa "MVVM leve" no Jordania e estabelece os limites entre Views, ViewModels e Services.

**Scope:** Responsabilidades de ViewModel, responsabilidades de View, responsabilidades de Core, gerenciamento de estado e padrões do código existente. Mecânica de DI pertence a [DEPENDENCY_INJECTION.md](DEPENDENCY_INJECTION.md). Estilo de código pertence a [SWIFT_STYLE_GUIDE.md](SWIFT_STYLE_GUIDE.md). Raciocínio arquitetural pertence a [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md).

---

## Table of Contents

1. [Os Três Papéis](#os-três-papéis)
2. [Regras do ViewModel](#regras-do-viewmodel)
3. [Regras da View](#regras-da-view)
4. [Responsabilidades de Core](#responsabilidades-de-core)
5. [Ownership de Estado](#ownership-de-estado)
6. [Padrão de Ação Async](#padrão-de-ação-async)
7. [Apresentação de Erros](#apresentação-de-erros)
8. [Anti-Padrões](#anti-padrões)

---

## Os Três Papéis

| Camada | Possui | Nunca faz |
|---|---|---|
| **View** | Layout, animações, eventos de interação do usuário | Lógica de negócio, chamadas diretas a services, mutação de estado |
| **ViewModel** | Estado observável, métodos de ação, coordenação de services | Decisões de layout, acesso direto a Keychain / rede |
| **Service / Core** | Operações de domínio (rede, persistência, SDKs) | Estado observável, preocupações de UI |

MVVM leve não tem camada de Use Cases nem camada de Repository. ViewModels chamam services diretamente. Essa é uma simplificação deliberada — o custo de manutenção de camadas intermediárias supera o benefício para o tamanho e escopo atual do projeto.

---

## Regras do ViewModel

### Declaração canônica

Todo ViewModel é `@Observable @MainActor final class`:

```swift
// AuthViewModel.swift
@Observable
@MainActor
final class AuthViewModel {

    // MARK: - State
    var isLoading: Bool = false
    var errorMessage: String? = nil
    private var signInTask: Task<Void, Never>?

    // MARK: - Dependencies
    private let session: SessionStore
    private let appleAuthService: AppleAuthService
    private let googleAuthService: GoogleAuthService

    // MARK: - Init
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

- **`@Observable`** — observação granular: apenas propriedades acessadas pela View disparam re-render.
- **`@MainActor`** — todas as mutações de estado acontecem na main thread; sem `DispatchQueue.main.async` manual.
- **`final class`** — `@Observable` exige `class`; `final` previne subclassing não-intencional.

### Responsabilidades

- Expor **estado observável** que a View renderiza: `isLoading`, `errorMessage`, dados de domínio.
- Expor **métodos de ação** que a View chama: `signInWithGoogle()`, `handleAppleSignIn(_:)`, `signOut()`.
- Coordenar chamadas a services e atualizar estado com base nos resultados.
- Gerenciar o ciclo de vida de `Task` para operações async.
- **Não importar `SwiftUI`** (exceto tipos que fazem parte do modelo de dados SwiftUI, como `Color`).

### O que ViewModels nunca fazem

- Ler ou escrever no Keychain diretamente — isso pertence a `SessionPersistence` / `KeychainService`.
- Fazer chamadas `URLSession` diretamente — isso pertence a `APIClient`.
- Conter lógica de layout ou visual.
- Construir seus próprios services — services são injetados no `init`.
- Criar `Task` dentro de `body` de uma View — isso pertence ao ViewModel.

---

## Regras da View

### Ownership do ViewModel

Views possuem seu ViewModel via `@State`. Quando o ViewModel precisa de valor injetado, crie-o no `init` da View:

```swift
// AuthView.swift
struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel: AuthViewModel

    init(session: SessionStore) {
        _viewModel = State(initialValue: AuthViewModel(session: session))
    }

    var body: some View {
        // apenas layout e eventos
    }
}
```

Esse padrão garante:
1. O ViewModel é criado uma única vez e sobrevive a mudanças de identidade da View.
2. O ViewModel recebe suas dependências no momento da criação, não lazily.
3. Sem lookup ambiente de services.

### Responsabilidades da View

- Ler propriedades do ViewModel e renderizá-las.
- Chamar métodos de ação do ViewModel em resposta a interações do usuário.
- Gerenciar estado de apresentação local (`@State` booleans para sheet/alert).
- Extrair subviews privadas para organização visual.

### O que Views nunca fazem

- Conter `if`/`switch` que implementam regras de negócio.
- Chamar services, `SessionStore` ou `APIClient` diretamente.
- Criar blocos `Task` que realizam trabalho de domínio — delegue ao ViewModel.
- Conter lógica de formatação complexa em `body` — extraia para propriedade ou método.

---

## Responsabilidades de Core

`Core/` contém código que não pertence a nenhuma feature específica mas é necessário para várias.

| Módulo | Responsabilidade | Tipo Swift |
|---|---|---|
| `Core/Session/SessionStore` | Fonte única de verdade do estado de autenticação | `@Observable @MainActor final class` |
| `Core/Session/SessionPersistence` | Leitura/escrita de sessão e tokens no Keychain | `final class` |
| `Core/Session/AuthenticatedUser` | Modelo do usuário autenticado | `struct` |
| `Core/Session/SessionState` | Estados possíveis da sessão | `enum` |
| `Core/Authentication/AppleAuthService` | Fluxo Sign in with Apple | `struct` |
| `Core/Authentication/GoogleAuthService` | Fluxo Google Sign-In | `struct` |
| `Core/Authentication/BackendAuthService` | Troca de tokens com o backend | `struct` |
| `Core/Authentication/TokenProvider` | Refresh proativo + coalescing | `actor` |
| `Core/Networking/APIClient` | Execução de requests HTTP autenticados | `actor` |
| `Core/Security/KeychainService` | Primitivas de Keychain | `struct` |

**Regra:** Core não importa nada de `Features/`. Features importam de Core. Nunca o contrário.

---

## Ownership de Estado

| Tipo de estado | Dono | Mecanismo |
|---|---|---|
| Loading / erro durante uma ação | ViewModel | `var isLoading: Bool`, `var errorMessage: String?` |
| Estado de autenticação | `SessionStore` | `@Observable` observado por `RootView` |
| Usuário atual | `SessionStore.currentUser` | Propagado via `@Environment` ou passagem explícita |
| Navigation path (features futuras) | ViewModel raiz da feature | `var path: NavigationPath` |
| Visibilidade de sheet / alert | View | `@State var isSheetPresented: Bool` |
| Refresh token em voo | `TokenProvider` | `private var refreshTask: Task<String, Error>?` |

**Regra:** estado que afeta múltiplas views pertence ao ancestral comum mais alto ou a `SessionStore`. Estado local a uma view é `@State` nessa View.

---

## Padrão de Ação Async

`AuthViewModel.performSignIn(_:)` é o padrão canônico para todas as ações async em ViewModels:

```swift
// AuthViewModel.swift
private func performSignIn(_ operation: @escaping () async throws -> AuthSession) {
    guard signInTask == nil else { return }   // ① evita submissão concorrente
    isLoading = true
    signInTask = Task {
        defer {
            isLoading = false                  // ② teardown em qualquer caminho de saída
            signInTask = nil
        }
        do {
            let authSession = try await operation()
            session.signIn(
                user: authSession.user,
                accessToken: authSession.accessToken,
                refreshToken: authSession.refreshToken
            )
        } catch AuthError.cancelled, NetworkError.cancelled {
            // ③ silencioso — cancelamento iniciado pelo usuário
        } catch let networkError as NetworkError {
            errorMessage = networkError.errorDescription ?? "Tente novamente."
        } catch {
            errorMessage = "Não foi possível concluir o login. Tente novamente."
        }
    }
}
```

Propriedades obrigatórias do padrão:

1. **Guard contra execução concorrente** — `guard signInTask == nil` previne duplo submit.
2. **`defer` para teardown** — `isLoading` e `signInTask` sempre são resetados, inclusive em early exit.
3. **Tratamento tipado de cancelamento** — `AuthError.cancelled` e `NetworkError.cancelled` são descartados silenciosamente.
4. **Tratamento tipado de erros** — erros conhecidos mapeiam para mensagens específicas; desconhecidos recebem fallback genérico.
5. **Mutações de estado no `@MainActor`** — sem despacho manual para a main thread.

Novas ações async em outros ViewModels **devem seguir essa mesma estrutura**.

---

## Apresentação de Erros

- ViewModels expõem `var errorMessage: String?`.
- Views vinculam isso a um `.alert` ou texto de erro inline.
- `nil` significa que nenhum erro está sendo exibido.
- O ViewModel limpa `errorMessage` antes de iniciar uma nova operação.
- **Nunca** mostre `error.localizedDescription` bruto — use sempre `error.errorDescription` de conformances `LocalizedError`, ou um fallback hardcoded.
- Erros de cancelamento (`AuthError.cancelled`, `NetworkError.cancelled`) nunca produzem mensagens na UI.

---

## Anti-Padrões

| Anti-padrão | Problema | Correção |
|---|---|---|
| ViewModel importa `SwiftUI` para lógica visual | Acoplamento de UI | Mova a lógica visual para a View |
| View chama `APIClient` ou `KeychainService` diretamente | Bypassa a camada de ViewModel | Roteie por um método de ação do ViewModel |
| Múltiplas Tasks concorrentes para a mesma ação | Race conditions, atualizações de estado duplicadas | Guard com propriedade `Task?` armazenada |
| `ObservableObject` / `@Published` | Superado por `@Observable` | Migre para `@Observable` |
| ViewModel construído dentro de `body` | Recriado a cada render | Possua via `@State` no `init` |
| Lógica de negócio em `body` | Não testável, separação ruim | Extraia para método do ViewModel |
| Service Locator ou singleton global | Dependências ocultas | Injeção por inicializador (ver [DEPENDENCY_INJECTION.md](DEPENDENCY_INJECTION.md)) |
| Modelo de domínio em `Shared/` | Acoplamento entre features | Modelos pertencem à sua feature ou a `Core/Session` |
