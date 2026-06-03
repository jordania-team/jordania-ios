# AI Engineering Rules — Jordania

Documento de diretrizes técnicas do projeto. O objetivo é manter consistência de engenharia, qualidade de código e alinhamento arquitetural ao longo do desenvolvimento — especialmente em decisões que envolvem IA, sugestões de implementação e tasks técnicas.

---

## Filosofia do projeto

O Jordania está em fase de challenge/POC. A equipe é pequena, o backend ainda está evoluindo, e o foco principal é iOS. As decisões técnicas devem refletir isso.

**Priorizar:**
- Simplicidade e clareza acima de tudo
- Manutenção futura — código que outro dev consiga entender sem explicação
- Velocidade de iteração — validar rápido, evoluir com segurança
- Arquitetura limpa com responsabilidades claras
- UX nativa iOS — seguir as HIG, não brigar com o sistema

**Evitar:**
- Overengineering — não construir para problemas que não existem ainda
- Abstrações prematuras — generalizar só quando a necessidade for real
- Camadas artificiais — cada camada precisa ter razão de existir
- Arquitetura enterprise em um produto early-stage
- Código excessivamente genérico cedo demais

---

## Diretrizes de engenharia

Toda sugestão técnica deve seguir:

- **Separação de responsabilidades** — cada classe faz uma coisa, faz bem
- **Baixo acoplamento** — mudanças em uma parte não devem quebrar outra
- **Alta legibilidade** — código é lido muito mais do que escrito
- **Código idiomático** — Swift moderno, padrões que iOS engineers reconhecem
- **Modularização quando fizer sentido** — não antes

Ao propor uma solução, sempre:
- Explicar os tradeoffs relevantes
- Justificar decisões arquiteturais que não são óbvias
- Avisar quando algo estiver complexo demais para o estágio do produto
- Preferir a solução mais simples que resolve o problema corretamente

---

## Diretrizes iOS

O desenvolvimento iOS deve seguir:

- **Swift moderno** — concorrência com `async/await`, `Observation`, tipos value quando fizer sentido
- **SwiftUI first** — UIKit só quando não houver alternativa
- **APIs nativas da Apple** — preferir o ecossistema Apple antes de SDKs externos
- **Human Interface Guidelines** — decisões de UX alinhadas com o que o usuário iOS espera
- **Acessibilidade** — não é opcional, é parte da qualidade
- **Performance** — lazy loading, evitar trabalho na main thread

Evitar:
- Padrões UIKit sem necessidade real
- Soluções que destoem da experiência nativa iOS
- Dependência excessiva de SDKs de terceiros quando a Apple já resolve

---

## Arquitetura

A arquitetura do projeto deve:

- Ser fácil de evoluir incrementalmente
- Manter responsabilidades claras entre camadas (UI, domínio, dados, rede)
- Permitir trocar implementações sem reescrever tudo — ex: trocar mock por backend real sem tocar na UI
- Evitar dependência forte de SDKs externos nas camadas de domínio

Não criar:
- Múltiplas camadas sem necessidade concreta
- Abstrações "para o futuro" que não resolvem nada hoje
- Protocolos e generics onde tipos concretos resolvem

---

## Backend

Stack atual: **Java Spring Boot + PostgreSQL**, com deploy planejado na AWS.

Princípios para a integração iOS ↔ backend:

- **Contratos claros** — o iOS depende apenas do formato do JSON, não da implementação do servidor
- **APIs simples** — endpoints com responsabilidade única, sem lógica misturada
- **Autenticação organizada** — JWT gerado pelo backend (JJWT), iOS trata como `String` e envia no header `Authorization: Bearer`
- **Facilidade de evolução** — o iOS não deve mudar quando o backend muda internamente

---

## Como responder tasks técnicas

Ao sugerir implementações:

1. Dividir em etapas pequenas e incrementais
2. Explicar o racional técnico — não só o "o quê" mas o "por quê"
3. Manter foco pragmático — o que resolve o problema agora, com espaço para evoluir
4. Não assumir requisitos não definidos
5. Evitar respostas excessivamente teóricas — código real, decisões reais

O tom deve ser o de um tech lead experiente orientando um produto early-stage: direto, claro, sem cerimônia desnecessária.

---

## Onde usar este documento

- **Antes de começar uma task técnica** — releia as diretrizes para garantir alinhamento
- **Em revisões de código** — use como referência para justificar ou questionar decisões
- **Ao integrar IA no desenvolvimento** — este arquivo orienta o contexto que deve ser dado em cada sessão
- **Em decisões arquiteturais** — quando surgir dúvida entre duas abordagens, as diretrizes aqui ajudam a desempatar
