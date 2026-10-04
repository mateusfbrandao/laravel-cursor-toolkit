## name: formulario-modal-inertia

description: Cria e gerencia formulários e confirmações reativas em janelas modais (Dialog ou Sheet do shadcn-vue) integrados ao ciclo de vida do Inertia.js (useForm), tratando estados de carregamento, erros de validação, sincronização de props, acessibilidade e prevenção de perda de dados.

# Skill: Formulários em Modais & Gavetas (Inertia + shadcn-vue)

Esta skill estabelece o padrão arquitetural e de interface para criar e editar registros dentro de diálogos modais (`Dialog`) ou painéis deslizantes laterais (`Sheet`) no ecossistema **Laravel + Inertia.js + Vue 3 + shadcn-vue**.

Siga este procedimento para evitar recarregamentos desnecessários de tela, retenção indevida de dados no estado reativo (*stale state*), fechamentos acidentais durante submissões e inconsistências visuais.

---

## Etapa 1: Componentes shadcn-vue Necessários

Antes de construir o modal, verifique se os componentes necessários constam em `resources/js/components/ui/`:

1. `dialog` (`Dialog`, `DialogTrigger`, `DialogContent`, `DialogHeader`, `DialogFooter`, `DialogTitle`, `DialogDescription`, `DialogClose`)
2. `sheet` (caso o design exija gaveta lateral para formulários com muitos campos)
3. `button` (`Button`)
4. `input` (`Input`)
5. `label` (`Label`)
6. `textarea` (`Textarea` — quando aplicável)
7. `select` (`Select`, `SelectTrigger`, `SelectValue`, `SelectContent`, `SelectItem` — quando aplicável)

Caso falte algum componente, utilize a skill `@add-shadcn-component`:

```bash
npx shadcn-vue@latest add dialog sheet input label textarea --yes
```

---

## Etapa 2: Definição dos Contratos de Props e Tipos TypeScript

Isole o modal em um componente dedicado (ex.: `resources/js/pages/Products/Partials/ProductFormDialog.vue`) em vez de inflar o arquivo principal `Index.vue`.

Crie a interface de dados e propriedades:

```typescript
export interface ProductFormData {
  name: string;
  sku: string;
  price: number | string;
  status: 'draft' | 'active' | 'archived';
  description?: string | null;
}

export interface ProductItem extends ProductFormData {
  id: number;
  created_at: string;
}
```

No componente do modal, defina o contrato com `v-model:open`:

```typescript
interface Props {
  open: boolean;
  item?: ProductItem | null; // null ou undefined = Modo Criação; Preenchido = Modo Edição
}

interface Emits {
  (e: 'update:open', value: boolean): void;
  (e: 'success', item?: ProductItem): void;
}
```

---

## Etapa 3: Implementação do Componente Modal (`ProductFormDialog.vue`)

Crie o arquivo em `resources/js/pages/{Entities}/Partials/{Entity}FormDialog.vue` seguindo a estrutura abaixo:

```vue
<script setup lang="ts">
import { computed, watch } from 'vue';
import { useForm } from '@inertiajs/vue3';
import { Loader2, PackagePlus, Pencil } from 'lucide-vue-next';

import { ProductItem } from '@/types/products';
import { store, update } from '@/routes/products';

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

interface Props {
  open: boolean;
  item?: ProductItem | null;
}

const props = withDefaults(defineProps<Props>(), {
  open: false,
  item: null,
});

const emit = defineEmits<{
  (e: 'update:open', value: boolean): void;
  (e: 'success'): void;
}>();

// Modo derivado: Se 'item' possui ID, estamos editando
const isEditing = computed(() => Boolean(props.item?.id));

// Inicialização reativa do formulário Inertia
const form = useForm({
  name: '',
  sku: '',
  price: '' as number | string,
  status: 'draft' as 'draft' | 'active' | 'archived',
  description: '',
});

// Sincronização estrita de estado ao abrir ou alternar o item selecionado
watch(
  () => [props.open, props.item],
  ([isOpen, currentItem]) => {
    if (!isOpen) return;

    if (currentItem && typeof currentItem === 'object' && 'id' in currentItem) {
      form.clearErrors();
      form.name = currentItem.name ?? '';
      form.sku = currentItem.sku ?? '';
      form.price = currentItem.price ?? '';
      form.status = currentItem.status ?? 'draft';
      form.description = currentItem.description ?? '';
    } else {
      form.reset();
      form.clearErrors();
      form.status = 'draft';
    }
  },
  { immediate: true }
);

// Fechamento seguro: impede interrupções durante o processamento ativo
function handleOpenChange(value: boolean) {
  if (form.processing) return;

  if (!value) {
    form.reset();
    form.clearErrors();
  }
  emit('update:open', value);
}

// Submissão tipada com Laravel Wayfinder
function submit() {
  if (isEditing.value && props.item) {
    form.put(update({ product: props.item.id }).url, {
      preserveScroll: true,
      onSuccess: () => {
        handleOpenChange(false);
        emit('success');
      },
    });
  } else {
    form.post(store().url, {
      preserveScroll: true,
      onSuccess: () => {
        handleOpenChange(false);
        emit('success');
      },
    });
  }
}
</script>

<template>
  <Dialog :open="open" @update:open="handleOpenChange">
    <DialogContent
      class="sm:max-w-[500px]"
      @interact-outside.prevent="form.processing && $event.preventDefault()"
      @escape-key-down.prevent="form.processing && $event.preventDefault()"
    >
      <form @submit.prevent="submit" class="space-y-5">
        <!-- Cabeçalho Acessível -->
        <DialogHeader>
          <div class="flex items-center gap-2">
            <div class="rounded-md bg-muted p-2 text-foreground">
              <Pencil v-if="isEditing" class="h-4 w-4" />
              <PackagePlus v-else class="h-4 w-4" />
            </div>
            <div>
              <DialogTitle>
                {{ isEditing ? 'Editar Produto' : 'Cadastrar Novo Produto' }}
              </DialogTitle>
              <DialogDescription class="text-xs">
                {{
                  isEditing
                    ? 'Altere os dados do produto abaixo e clique em salvar.'
                    : 'Preencha os campos obrigatórios (*) para criar o registro.'
                }}
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        <!-- Corpo do Formulário -->
        <div class="space-y-4 py-2">
          <!-- Campo Nome -->
          <div class="space-y-1.5">
            <Label for="product-name" class="text-xs font-semibold">
              Nome do Produto <span class="text-destructive">*</span>
            </Label>
            <Input
              id="product-name"
              v-model="form.name"
              placeholder="Ex.: Teclado Mecânico RGB"
              :disabled="form.processing"
              :class="{ 'border-destructive focus-visible:ring-destructive': form.errors.name }"
              autocomplete="off"
            />
            <p v-if="form.errors.name" class="text-xs font-medium text-destructive">
              {{ form.errors.name }}
            </p>
          </div>

          <!-- Grade SKU e Preço -->
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div class="space-y-1.5">
              <Label for="product-sku" class="text-xs font-semibold">
                SKU / Código <span class="text-destructive">*</span>
              </Label>
              <Input
                id="product-sku"
                v-model="form.sku"
                placeholder="TEC-MEC-01"
                class="font-mono uppercase"
                :disabled="form.processing"
                :class="{ 'border-destructive focus-visible:ring-destructive': form.errors.sku }"
                autocomplete="off"
              />
              <p v-if="form.errors.sku" class="text-xs font-medium text-destructive">
                {{ form.errors.sku }}
              </p>
            </div>

            <div class="space-y-1.5">
              <Label for="product-price" class="text-xs font-semibold">
                Preço (R$) <span class="text-destructive">*</span>
              </Label>
              <Input
                id="product-price"
                v-model="form.price"
                type="number"
                step="0.01"
                min="0"
                placeholder="0,00"
                class="font-mono tabular-nums text-right"
                :disabled="form.processing"
                :class="{ 'border-destructive focus-visible:ring-destructive': form.errors.price }"
              />
              <p v-if="form.errors.price" class="text-xs font-medium text-destructive">
                {{ form.errors.price }}
              </p>
            </div>
          </div>

          <!-- Campo Status com Select shadcn -->
          <div class="space-y-1.5">
            <Label for="product-status" class="text-xs font-semibold">Status Inicial</Label>
            <Select v-model="form.status" :disabled="form.processing">
              <SelectTrigger id="product-status" class="w-full">
                <SelectValue placeholder="Selecione um status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="draft">Rascunho</SelectItem>
                <SelectItem value="active">Ativo</SelectItem>
                <SelectItem value="archived">Arquivado</SelectItem>
              </SelectContent>
            </Select>
            <p v-if="form.errors.status" class="text-xs font-medium text-destructive">
              {{ form.errors.status }}
            </p>
          </div>
        </div>

        <!-- Rodapé de Ações -->
        <DialogFooter class="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button
            type="button"
            variant="outline"
            :disabled="form.processing"
            @click="handleOpenChange(false)"
          >
            Cancelar
          </Button>

          <Button type="submit" :disabled="form.processing">
            <Loader2 v-if="form.processing" class="mr-2 h-4 w-4 animate-spin" />
            {{ isEditing ? 'Salvar Alterações' : 'Criar Registro' }}
          </Button>
        </DialogFooter>
      </form>
    </DialogContent>
  </Dialog>
</template>
```

---

## Etapa 4: Integração com a Tela Principal (`Index.vue`)

Consuma o componente modular no arquivo principal de listagem:

```vue
<script setup lang="ts">
import { ref } from 'vue';
import { Plus, Pencil, MoreHorizontal } from 'lucide-vue-next';
import { ProductItem, PaginatedResponse, TableFilters } from '@/types/products';

import ProductFormDialog from './Partials/ProductFormDialog.vue';
import { Button } from '@/components/ui/button';

defineProps<{
  items: PaginatedResponse<ProductItem>;
  filters: TableFilters;
}>();

// Estado do modal
const isFormOpen = ref(false);
const selectedProduct = ref<ProductItem | null>(null);

function handleCreate() {
  selectedProduct.value = null;
  isFormOpen.value = true;
}

function handleEdit(item: ProductItem) {
  selectedProduct.value = item;
  isFormOpen.value = true;
}
</script>

<template>
  <div class="p-6 space-y-6">
    <!-- Gatilho de Criação -->
    <div class="flex justify-between items-center">
      <h1 class="text-2xl font-bold tracking-tight">Catálogo de Produtos</h1>
      <Button @click="handleCreate">
        <Plus class="mr-2 h-4 w-4" /> Novo Produto
      </Button>
    </div>

    <!-- Tabela ou Listagem existente... (botão de edição invoca handleEdit(item)) -->

    <!-- Instância do Modal -->
    <ProductFormDialog
      v-model:open="isFormOpen"
      :item="selectedProduct"
    />
  </div>
</template>
```

---

## Etapa 5: Variação em Painel Deslizante Lateral (`Sheet`)

Para formulários com mais de 5 a 6 campos, substitua o `Dialog` por um `Sheet` lateral para evitar barras de rolagem apertadas:

1. Importe de `@/components/ui/sheet`:
   ```typescript
   import {
     Sheet,
     SheetContent,
     SheetDescription,
     SheetFooter,
     SheetHeader,
     SheetTitle,
   } from '@/components/ui/sheet';
   ```
2. Defina o posicionamento lateral (`side="right"`) e largura responsiva:
   ```vue
   <Sheet :open="open" @update:open="handleOpenChange">
     <SheetContent side="right" class="w-full sm:max-w-lg overflow-y-auto">
       <!-- Formulário correspondente -->
     </SheetContent>
   </Sheet>
   ```

---

## Etapa 6: Checklist de Qualidade Impeccable (Audit)

Antes de considerar o modal finalizado, verifique:

1. **Prevenção de Perda de Dados:**
   - [ ] Eventos `@interact-outside.prevent` e `@escape-key-down.prevent` bloqueiam o fechamento se `form.processing` for verdadeiro.
2. **Higiene de Erros e Cache Reativo:**
   - [ ] `form.clearErrors()` e `form.reset()` são executados sempre que o modal é aberto ou fechado.
   - [ ] O `watch` de sincronização avalia tanto `props.open` quanto `props.item`.
3. **Acessibilidade (A11y):**
   - [ ] Todos os campos `<Input />` possuem um `<Label>` correspondente com atributo `for` casado com o `id`.
   - [ ] Mensagens de erro de validação contam com contraste visível (`text-destructive`).
4. **Alinhamento Numérico:**
   - [ ] Campos monetários e numéricos utilizam `font-mono tabular-nums text-right`.
5. **Microinterações:**
   - [ ] O botão primário de submissão exibe o `<Loader2 class="animate-spin" />` enquanto `form.processing` estiver ativo e fica desabilitado.