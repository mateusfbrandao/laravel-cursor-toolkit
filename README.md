# Laravel Vibe Toolkit

Ecossistema de engenharia de software e governança para aplicações de alto nível com **Laravel**, **Vue 3**, **Inertia.js**, **shadcn-vue** e **Tailwind CSS**, orquestrado nativamente pelo editor Cursor via Agentes Especializados, Skills Operacionais, Design System Impeccable e aceleração com Laravel Boost.

---

## 🛠️ Stack Tecnológica

- **Backend:** Laravel 12+, Slim Controllers, Actions invocáveis, DTOs imutáveis (`readonly class`).
- **Performance & DX:** [Laravel Boost](https://github.com/laravel/boost) (otimização de arranque do container e metadados contextuais para assistentes de código).
- **Frontend:** Vue 3 (Composition API com `<script setup lang="ts">`), Inertia.js, shadcn-vue, Tailwind CSS, Laravel Wayfinder.
- **Design & Polish:** [Impeccable](https://impeccable.style/) (tokens de interface, microinterações e conformidade A11y).
- **Qualidade & Tipos:** Larastan (Nível 8 estrito com suporte a Baseline), Laravel Pint (PSR-12), Pest PHP (5 pilares), Vitest.
- **Governança CI/CD:** GitHub Actions com execução paralela de testes e linters para backend e frontend.

---

## 👥 Agentes Especializados (`.cursor/agents/`)

Agentes concebidos para operar com responsabilidades bem delimitadas. Podem ser ativados de modo automático ou referenciados com `@`:

| Agente | Ficheiro | Responsabilidade Principal |
| :--- | :--- | :--- |
| **Arquiteto Backend** | `@arquiteto-backend.md` | Slim Controllers, Actions de domínio, DTOs imutáveis e Services. |
| **Arquiteto Frontend** | `@especialista-frontend.md` | Interfaces Vue 3 tipadas, modais com Inertia.js e componentes shadcn-vue. |
| **Revisor de Código** | `@revisor-codigo.md` | Inspeção dos 5 pilares: Estrutura, Tipagem (Larastan 8), Actions, Pint e Segurança. |
| **Especialista em Banco** | `@especialista-banco.md` | Migrations resilientes, indexação estratégica e eliminação de queries $N+1$. |
| **Auditor de Segurança** | `@auditor-seguranca.md` | Prevenção de IDOR, Policies e isolamento multi-tenant (banco, coluna ou monousuário). |
| **Engenheiro de Testes** | `@engenheiro-testes.md` | Testes automatizados com Pest PHP (Backend) e Vitest (Frontend). |
| **Integrador de APIs** | `@integrador-apis.md` | Consumo de WebServices externos, tratamento idempotente de Webhooks e Jobs. |
| **Engenheiro DevOps** | `@engenheiro-devops.md` | Pipelines de CI/CD para GitHub Actions, gestão de cache e automação. |

---

## ⚡ Skills Operacionais (`.cursor/skills/`)

Procedimentos de engenharia prontos para execução direta:

1. `@criar-modulo-crud`: Scaffold completo de domínios na arquitetura de 5 camadas.
2. `@criar-tabela-complexa`: Tabelas com ordenação, filtros compostos, paginação e estados vazios.
3. `@formulario-modal-inertia`: Diálogos modais com submissão assíncrona e tratamento de validações.
4. `@refatorar-action-dto`: Desacoplamento de controllers legados extraindo DTOs e Actions.
5. `@otimizar-query-eloquent`: Deteção de estrangulamentos, aplicação de *eager loading* e índices.
6. `@gerar-teste-pest`: Cobertura de backend estruturada nos 5 pilares de integridade.
7. `@gerar-teste-vitest`: Testes unitários de composables e componentes interativos em Vue 3.
8. `@auditoria-seguranca-tenant`: Inspeção contra fugas de contexto e ausência de escopos globais.
9. `@implementar-integracao-webhook`: Receção de eventos externos com validação criptográfica e filas.

---

## 🚀 Instalação e Execução

Para configurar o ecossistema num projeto Laravel alvo:

```bash
# Conceder permissão de execução
chmod +x apply-toolkit.sh

# Executar na raiz do projeto
./apply-toolkit.sh .