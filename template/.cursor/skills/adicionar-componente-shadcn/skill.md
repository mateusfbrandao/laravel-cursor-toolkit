## name: adicionar-componente-shadcn
description: Instala, configura e audita componentes do catálogo shadcn-vue no projeto, garantindo conformidade com o design system, Radix Vue, Lucide Icons, TypeScript estrito e os padrões de UI Craft (Impeccable Standard).

# Skill: Adicionar e Auditar Componente shadcn-vue

Esta skill define o procedimento padronizado para introduzir ou alinhar novos componentes do catálogo **shadcn-vue** em projetos que utilizam Vue 3 com Composition API, TailwindCSS e TypeScript.

Siga estritamente o fluxo sequencial de 5 etapas para evitar duplicação de primitivos, quebra de acessibilidade ou inconsistências visuais.

---

## Etapa 1: Verificação Prévia de Existência e Primitivos

Antes de executar qualquer comando de instalação, inspecione a árvore de componentes em `resources/js/components/ui/`:

1. **Checagem de Duplicação:**
   - Verifique se o componente desejado (ou um equivalente funcional) já existe. Por exemplo:
     - Não instale `modal` se `dialog` já existir.
     - Não instale `drawer` se `sheet` for suficiente para a gaveta lateral.
     - Não instale `alert-dialog` se um `dialog` com variantes já resolver a confirmação.
2. **Reutilização Obrigatória:**
   - Se o componente já existir, reutilize os blocos exportados diretamente em `@/components/ui/<componente>`.
   - NUNCA reescreva nem instale por cima sem necessidade explícita.

---

## Etapa 2: Instalação via CLI ou Servidor MCP

Execute a adição do componente a partir da raiz do projeto:

### 2.1 Via CLI shadcn-vue

Execute no terminal:

```bash
npx shadcn-vue@latest add {componente} --yes
```

Exemplos de componentes fundamentais:
```bash
# Diálogos, Sheets e Menus Suspensos
npx shadcn-vue@latest add dialog --yes
npx shadcn-vue@latest add sheet --yes
npx shadcn-vue@latest add dropdown-menu --yes
npx shadcn-vue@latest add popover --yes
npx shadcn-vue@latest add tooltip --yes

# Formulários e Seletores
npx shadcn-vue@latest add select --yes
npx shadcn-vue@latest add checkbox --yes
npx shadcn-vue@latest add switch --yes
npx shadcn-vue@latest add textarea --yes

# Feedback e Navegação
npx shadcn-vue@latest add badge --yes
npx shadcn-vue@latest add tabs --yes
npx shadcn-vue@latest add skeleton --yes
npx shadcn-vue@latest add separator --yes
```

### 2.2 Via Servidor MCP (Quando Habilitado no Cursor)

Se o MCP `shadcn-vue` estiver ativo nas ferramentas do Cursor:
- Use a ferramenta `shadcn_vue_get_component` para inspecionar os arquivos e propriedades oficiais antes de instanciar.
- Solicite a instalação através da ferramenta correspondente do servidor MCP.

---

## Etapa 3: Auditoria do Código Gerado (Checklist Obrigatório)

Logo após os arquivos serem gravados em `resources/js/components/ui/{componente}/`, você **DEVE** realizar a auditoria dos seguintes itens:

### 3.1 Caminho do Helper `cn()`
* Inspecione os imports de utilitários em cada arquivo gerado (`index.ts`, `{Componente}.vue`).
* Garanta que a função `cn` está sendo importada estritamente de:
  ```typescript
  import { cn } from '@/lib/utils';
  ```
* Se a CLI gerar `@/utils` ou `../../lib/utils`, ajuste para o alias padronizado `@/lib/utils`.

### 3.2 Substituição de Ícones por `lucide-vue-next`
* O gerador oficial pode introduzir ícones de bibliotecas externas (como `@radix-icons/vue`).
* **Substitua imediatamente** qualquer ícone externo por seu correspondente na biblioteca `lucide-vue-next`:
  - `ChevronDownIcon` / `CaretSortIcon` $\rightarrow$ `ChevronDown` / `ChevronsUpDown` de `lucide-vue-next`.
  - `CheckIcon` $\rightarrow$ `Check` de `lucide-vue-next`.
  - `Cross2Icon` $\rightarrow$ `X` de `lucide-vue-next`.
  - `CircleIcon` $\rightarrow$ `Circle` de `lucide-vue-next`.

### 3.3 Preservação de Tipos e Primitivos Radix Vue
* Certifique-se de que os primitivos de acessibilidade do `radix-vue` foram instalados e mantidos intactos.
* Verifique se as dependências necessárias constam em `package.json`:
  - `radix-vue`
  - `class-variance-authority` (cva)
  - `clsx`
  - `tailwind-merge`

---

## Etapa 4: Aplicação no Projeto (Padrão Impeccable)

Ao consumir o componente em páginas (`resources/js/pages/`) ou componentes compartilhados (`resources/js/components/`):

### 4.1 Sintaxe e Importações
* Utilize exclusivamente `<script setup lang="ts">`.
* Importe os submódulos de forma limpa a partir de `@/components/ui/{componente}`:

```vue
<script setup lang="ts">
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
</script>
```

### 4.2 Proibição de HTML Cru
* **NUNCA** substitua componentes já disponíveis por tags HTML nativas equivalentes:
  - Utilize `<Button variant="...">` em vez de `<button class="...">`.
  - Utilize `<Input />` em vez de `<input class="...">`.
  - Utilize `<Badge>` em vez de `<span class="bg-gray-200 ...">`.
  - Utilize `<Table>`, `<TableRow>`, `<TableCell>` em vez de `<table>`, `<tr>`, `<td>`.

### 4.3 Regras de Estilização e Tokens Tailwind
* Respeite os tokens semânticos de cor do tema (`bg-background`, `text-foreground`, `bg-card`, `text-muted-foreground`, `border-border`, `ring-ring`).
* **NUNCA** utilize valores arbitrários manuais para espaçamentos ou posições (ex.: `p-[13px]`, `top-[18px]`). Use a escala padrão (`p-3`, `p-4`, `top-4`, `gap-6`).
* Para customizações contextuais de classes, use a prop `class="..."` passando utilitários do Tailwind; a mesclagem automática será processada pelo `cn()`.

### 4.4 Acessibilidade & Microinterações (A11y)
* Todo botão contendo exclusivamente ícone DEVE conter `aria-label`:
  ```vue
  <Button variant="ghost" size="icon" aria-label="Fechar diálogo">
    <X class="h-4 w-4" />
  </Button>
  ```
* Garanta foco navegável por teclado em diálogos, menus e selects (respeitando o trap-focus nativo do Radix Vue).
* Sempre que o componente disparar uma ação assíncrona, envolva com feedback animado:
  ```vue
  <Button :disabled="form.processing" type="submit">
    <Loader2 v-if="form.processing" class="mr-2 h-4 w-4 animate-spin" />
    Salvar alterações
  </Button>
  ```

---

## Etapa 5: Validação de Tipagem TypeScript

Após a instalação e o uso do componente, execute a checagem de tipos estáticos do frontend no terminal:

```bash
# Validação de TypeScript nos arquivos Vue e TS
npx vue-tsc --noEmit
```

Se o compilador reportar erros de tipagem em props ou eventos (`v-model`, `defineEmits`), resolva as interfaces antes de sugerir o commit.