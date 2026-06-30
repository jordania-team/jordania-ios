# Swift Style Guide

**Purpose:** Estabelece as convenções de código para todos os arquivos Swift do projeto Jordania. Estilo consistente reduz o custo cognitivo de ler código não familiar.

**Scope:** Formatação, nomenclatura, controle de acesso, organização de tipos, async/await, Observation (`@Observable`) e Strict Concurrency. Convenções de arquitetura e MVVM pertencem a [MVVM_GUIDELINES.md](MVVM_GUIDELINES.md). Injeção de dependência pertence a [DEPENDENCY_INJECTION.md](DEPENDENCY_INJECTION.md). Regras proibidas ficam em [../architecture/ENGINEERING_RULES.md](../architecture/ENGINEERING_RULES.md).

---

## Table of Contents

1. [Formatação](#formatação)
2. [Organização de MARK](#organização-de-mark)
3. [Nomenclatura](#nomenclatura)
4. [Controle de Acesso](#controle-de-acesso)
5. [Tipos e Declarações](#tipos-e-declarações)
6. [Extensions](#extensions)
7. [Async/Await](#asyncawait)
8. [Observation — @Observable](#observation--observable)
9. [Strict Concurrency](#strict-concurrency)
10. [Tratamento de Erros](#tratamento-de-erros)
11. [Comentários e Documentação](#comentários-e-documentação)
12. [SwiftUI](#swiftui)

---

## Formatação

- **Indentação:** 4 espaços. Nunca tabs.
- **Limite de linha:** Soft limit de 120 caracteres. Quebre assinaturas longas alinhando parâmetros sob o primeiro label.
- **Trailing whitespace:** Nunca. Ative *Trim trailing whitespace* nas preferências do Xcode.
- **Linhas em branco:** Uma linha em branco entre seções `MARK`. Nunca duas linhas em branco consecutivas.
- **Chaves:** Abre na mesma linha. Fecha em linha própria.

```swift
// ✅ Correto
func signOut() {
    currentUser = nil
    state = .signedOut
}

// ❌ Errado
func signOut()
{
    currentUser = nil
}
```

---

## Organização de MARK

Toda `class`, `struct` ou `actor` com mais de um grupo lógico deve usar `// MARK: - Nome` para separar seções. Ordem padrão:

1. Tipos aninhados e enums
2. Propriedades observáveis / estado (armazenadas, depois computadas)
3. Dependências (`private let`)
4. `init`
5. Métodos públicos / internos
6. Métodos privados

```swift
// Exemplo real — SessionStore.swift

// MARK: - State
private(set) var currentUser: AuthenticatedUser?
private(set) var state: SessionState = .loading

// MARK: - Dependencies
private let persistence: SessionPersistence

// MARK: - Init
init(persistence: SessionPersistence = SessionPersistence()) { … }

// MARK: - Actions
func signIn(user: AuthenticatedUser, accessToken: String, refreshToken: String) { … }
func signOut() { … }
func validateSession(using userService: UserService) async { … }

// MARK: - Private
private func configureGoogleSignIn() { … }
```

Em `AuthViewModel`, a seção de dependências e estado fica logo após a declaração da classe, antes de `init`, conforme o código existente.

---

## Nomenclatura

| Elemento | Convenção | Exemplos do projeto |
|---|---|---|
| Tipos | `UpperCamelCase` | `AuthViewModel`, `SessionStore`, `NetworkError` |
| Propriedades e métodos | `lowerCamelCase` | `currentUser`, `isLoading`, `signOut()` |
| Constantes | `lowerCamelCase` | `service`, `refreshTask` |
| Cases de enum | `lowerCamelCase` | `.authenticated`, `.signedOut`, `.loading`, `.error` |
| Booleanos | prefixo `is`/`has`/`can`/`should` | `isLoading`, `JWT.isExpired(_:)`, `JWT.needsRefresh(_:)` |
| Funções async | nome pelo resultado, não pela operação | `fetchCurrentUser()`, `validAccessToken()` |
| Tipos de erro | sufixo `Error` | `AuthError`, `NetworkError` |
| Services | sufixo `Service` | `AppleAuthService`, `BackendAuthService`, `UserService` |
| ViewModels | sufixo `ViewModel` | `AuthViewModel` |
| Views raiz de feature | sem sufixo | `AuthView`, `FeedView`, `ProfileView` |

### Regras anti-ruído

- Não repetir o nome do tipo na propriedade: `session.currentUser`, nunca `session.currentUserObject`.
- Não prefixar com o módulo: `AuthError`, nunca `JordaniaAuthError`.
- Sem abreviações além de universalmente aceitas (`URL`, `ID`, `JWT`). Nunca `mgr`, `svc`, `vm`, `vc`.
- Nomes de parâmetros externos devem ler-se como prosa: `signIn(user:accessToken:refreshToken:)`, `validated(using:)`.

---

## Controle de Acesso

**Regra-base: use o nível mais restritivo possível e escale apenas quando necessário.**

- **`private`** para tudo que o arquivo não precisa exportar.
- **`private(set)`** para propriedades observáveis que tipos externos devem ler mas não mutar diretamente:

```swift
// SessionStore.swift — estado observável, mutação só via métodos
private(set) var currentUser: AuthenticatedUser?
private(set) var state: SessionState = .loading
```

- **`internal`** é o padrão implícito. Escreva-o apenas quando a clareza exigir.
- **`public`** nunca é usado. O projeto é um único target sem superfície de API pública.
- **`final`** em todas as `class` a menos que herança seja explicitamente necessária e documentada. `@Observable` exige `class`; `final` previne subclassing acidental.
- **`fileprivate`** apenas para extensões no mesmo arquivo que precisam de acesso entre tipos distintos — use com parcimônia.

---

## Tipos e Declarações

- **Prefira `struct` a `class`.** Use `class` apenas quando semânticas de identidade, `@Observable` ou `deinit` forem necessários.
- **Prefira `enum` com associated values a múltiplos Bool flags.** `SessionState` é o padrão canônico: `.loading`, `.authenticated`, `.signedOut`, `.error(String)` — não `isLoading: Bool` + `isAuthenticated: Bool` + `errorMessage: String?`.
- **Inferência de tipos sobre anotação explícita** quando o tipo é óbvio no ponto de declaração:

```swift
// ✅ Preferido
let store = SessionStore()
var isLoading = false

// ✅ Quando a clareza exige
var state: SessionState = .loading
private(set) var currentUser: AuthenticatedUser?
```

- **Sem `Any` ou `AnyObject`.** Use generics ou protocolos com associated types.
- **`guard` para saídas antecipadas** — trate estados inválidos no topo da função, antes do happy path:

```swift
// TokenProvider.swift
func validAccessToken() async throws -> String {
    guard let access = persistence.loadAccessToken() else {
        throw NetworkError.unauthorized
    }
    guard JWT.needsRefresh(access) else {
        return access
    }
    return try await performRefresh()
}
```

- **Sem force unwrap (`!`) em código de produção.** Use `guard let`, `if let`, `try` ou `try?` com tratamento adequado.

---

## Extensions

- **Extensions no mesmo arquivo** para conformances simples que não merecem arquivo próprio (ex: `Equatable`, `Hashable` em enums pequenos).
- **Extensions em arquivo separado** quando a conformance é substantiva: `NetworkError+LocalizedError.swift`, `AuthenticatedUser+Codable.swift`.
- **Nunca use extensions para contornar `private`.** Se o código precisa de acesso a membros privados, pertence ao mesmo tipo, não a uma extension.
- **Extensions de conveniência em tipos do SDK** ficam em `Shared/` se usados por mais de uma feature, ou no arquivo da feature se exclusivos.

```swift
// ✅ Conformance de protocolo em extension separada — NetworkError.swift
extension NetworkError: LocalizedError {
    var errorDescription: String? { … }
}

// ✅ DTO privado em extension no mesmo arquivo — UserService.swift
// MARK: - DTO
private struct UserMeResponse: Decodable { … }
```

---

## Async/Await

- **`async throws` para toda operação assíncrona.** Sem completion handlers, sem `Combine` para novas implementações.
- **`Task { }` em ViewModels**, nunca em Views. Views chamam métodos do ViewModel; o ViewModel cria e gerencia o `Task`.
- **`defer` para teardown** em blocos `Task` — garante reset de estado em qualquer caminho de saída:

```swift
// AuthViewModel.swift — padrão canônico
func performSignIn(_ operation: @escaping () async throws -> AuthSession) {
    guard signInTask == nil else { return }
    isLoading = true
    signInTask = Task {
        defer {
            isLoading = false
            signInTask = nil
        }
        // … operação
    }
}
```

- **`async let`** para operações paralelas independentes. Não serial quando paralelismo é possível.
- **`for await`** para AsyncSequence — não pollar nem usar timers para streams de eventos.
- **Nomeie funções async pelo resultado**: `validAccessToken()`, `fetchCurrentUser()` — não `performTokenFetch()`, `executeUserRequest()`.

---

## Observation — @Observable

`@Observable` (macro do framework `Observation`, iOS 17+) é o único mecanismo de estado reativo no projeto. `ObservableObject`/`@Published` são legados — nunca adicione novas conformances.

### Declaração canônica

```swift
// SessionStore.swift
@Observable
@MainActor
final class SessionStore {
    private(set) var currentUser: AuthenticatedUser?
    private(set) var state: SessionState = .loading
    // …
}
```

### Regras

- **`@Observable` exige `class`.** Não tente aplicar em `struct`.
- **Combine com `@MainActor`** para que mutações de estado ocorram sempre na main thread.
- **`private(set)` para estado observável** que Views lêem mas não devem mutar.
- **O JWT nunca aparece em propriedades observáveis.** `SessionStore` não expõe o access token — a UI não precisa dele. Veja `SessionStore.swift`.
- **Observação é granular.** `@Observable` re-renderiza apenas Views que acessaram a propriedade alterada — diferente de `ObservableObject` que invalida tudo. Aproveite isso: não agrupe estado não relacionado em um único objeto só para ter menos objetos.
- **`@Environment` para propagação de `SessionStore`** pela árvore de Views (ver [SwiftUI](#swiftui)).

---

## Strict Concurrency

O projeto usa Swift 6 com Strict Concurrency habilitado. Toda violação de isolamento é erro de compilação.

### Regras práticas

- **`@MainActor` em ViewModels e `SessionStore`** — mutações de estado UI sempre na main thread sem `DispatchQueue.main.async` manual.
- **`actor` para serviços com estado compartilhado entre tarefas concorrentes.** `TokenProvider` e `APIClient` são `actor` porque múltiplas Tasks podem chamá-los simultaneamente:

```swift
// TokenProvider.swift — actor para serializar acesso ao refreshTask
actor TokenProvider {
    private var refreshTask: Task<String, Error>?
    // …
}
```

- **`struct` e tipos sem estado são naturalmente Sendable.** `KeychainService`, `BackendAuthService`, `UserService` são `struct` — sem problemas de concorrência.
- **`weak var` para referências back-reference** que criariam retain cycle e problemas de isolamento:

```swift
// APIClient.swift e TokenProvider.swift
private weak var sessionStore: SessionStore?
```

- **Nunca use `@unchecked Sendable`** sem justificativa documentada em comentário `// SAFE:` explicando por quê é seguro.
- **`nonisolated` apenas quando o método genuinamente não acessa estado do ator.** Não use para contornar erros de compilação sem entender a implicação.
- **Coalescing de Tasks concorrentes** via propriedade `Task?` armazenada — padrão implementado em `TokenProvider.performRefresh()` e `AuthViewModel.performSignIn()`:

```swift
// Evita múltiplos refreshes simultâneos
if let existing = refreshTask {
    return try await existing.value   // coalescido
}
```

---

## Tratamento de Erros

- **Sempre use erros tipados.** `AuthError` para falhas de autenticação, `NetworkError` para transporte e HTTP. Nunca `throw NSError(…)` ou `throw "mensagem"`.
- **`errorDescription` é a única mensagem exibida ao usuário.** Nunca interpole `error.localizedDescription` diretamente em strings de UI.
- **Cancelamentos são silenciosos.** `AuthError.cancelled` e `NetworkError.cancelled` são capturados e descartados — nunca viram mensagem de erro:

```swift
// AuthViewModel.swift
} catch AuthError.cancelled, NetworkError.cancelled {
    // silencioso — cancelamento iniciado pelo usuário
} catch let networkError as NetworkError {
    errorMessage = networkError.errorDescription ?? "Tente novamente."
} catch {
    errorMessage = "Não foi possível concluir o login. Tente novamente."
}
```

- **`do`/`catch` com tipos explícitos em ViewModels** — erros conhecidos mapeiam para mensagens específicas; desconhecidos recebem fallback genérico.
- **Erros terminais não fazem retry.** `AuthError.sessionExpired` causa logout imediato — `TokenProvider` não tenta novamente após refresh rejeitado pelo backend.

---

## Comentários e Documentação

- **`///` (doc comment) em todos os tipos não-privados e métodos não-triviais não-privados.** Helpers privados auto-evidentes não precisam.
- **Explique o *porquê*, não o *o quê*.** O código já mostra o quê; o comentário explica intenção, restrições e decisões não óbvias:

```swift
/// A UI sempre desloga, mesmo se a limpeza do Keychain falhar.
func signOut() { … }

/// Coalescing: se várias chamadas simultâneas precisarem de refresh, apenas uma Task é criada
/// e as demais aguardam o mesmo resultado — evita condições de corrida e refreshes duplos.
actor TokenProvider { … }
```

- **Português ou inglês** são aceitos. Seja consistente dentro de um arquivo.
- **Sem código comentado** em arquivos commitados.
- **DTOs privados** ficam marcados com `// MARK: - DTO` no mesmo arquivo do service que os usa (veja `UserService.swift`).

---

## SwiftUI

- **`@State` para ownership de ViewModel em Views.** Quando o ViewModel depende de valor injetado, inicialize no `init` da View:

```swift
// AuthView.swift
struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel: AuthViewModel

    init(session: SessionStore) {
        _viewModel = State(initialValue: AuthViewModel(session: session))
    }
}
```

- **`@Environment` apenas para `SessionStore`.** É o único tipo propagado via `.environment()` na árvore de Views. Services, ViewModels e `AppContainer` nunca entram no environment.
- **Extraia subviews privadas** para componentes reutilizáveis ou que precisam ler `@Environment` no momento do render, não no momento de criação do pai. Veja `authButtonsSection` em `AuthView`.
- **Nenhuma lógica de negócio em `body`.** `body` computa árvore de views. Toda lógica — inclusive formatação simples — pertence a método auxiliar ou ViewModel.
- **Previews são obrigatórias** em todo arquivo de View. Servem como testes visuais leves e documentação viva.
- **`.safeAreaInset`** para ancorar conteúdo acima da safe area inferior — padrão em uso em `AuthView` para os botões de autenticação.
