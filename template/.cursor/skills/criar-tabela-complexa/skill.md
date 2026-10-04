## name: criar-tabela-complexa

description: Constrói telas de listagem e tabelas de dados complexas no Vue 3 com Inertia.js, shadcn-vue, filtros reativos debounced, ordenação por colunas, paginação fluida e padrão de UI Craft Impeccable.

# Skill: Construção de Tabelas de Dados Complexas (DataTables)

Esta skill estabelece o padrão arquitetural e de interface para listagens de dados de alta densidade no ecossistema **Laravel + Inertia.js + Vue 3 + shadcn-vue**.

Siga rigorosamente as etapas para garantir tabelas com excelente usabilidade, sem consultas $N+1$, com controle de histórico no navegador e transições fluidas.

---

## Etapa 1: Backend & Query de Listagem (Controller)

### 1.1 Prevenção de $N+1$ e Filtros com Eloquent
No Slim Controller da entidade (ex.: `ProductController::index`):
- Aplique *eager loading* explícito com `with([...])` em todos os relacionamentos exibidos na tabela.
- Isole a lógica de busca e ordenação usando `when()` condicional.
- Permita ordenação dinâmica com lista branca (*whitelist*) de colunas permitidas para evitar injeção de SQL ou quebras de ordenação.
- Retorne paginação preservando os query params com `withQueryString()`.

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\Product;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

final class ProductController extends Controller
{
    public function index(Request $request): Response
    {
        $this->authorize('viewAny', Product::class);

        $allowedSorts = ['id', 'name', 'price', 'status', 'created_at'];
        $sortBy = in_array($request->query('sort'), $allowedSorts, true) ? $request->query('sort') : 'id';
        $sortDirection = $request->query('direction') === 'asc' ? 'asc' : 'desc';

        $filters = [
            'search' => $request->query('search', ''),
            'status' => $request->query('status', ''),
            'sort' => $sortBy,
            'direction' => $sortDirection,
            'per_page' => (int) $request->query('per_page', 15),
        ];

        $items = Product::query()
            ->with(['category:id,name', 'creator:id,name'])
            ->when($filters['search'], function ($query, string $search): void {
                $query->where(function ($sub): void {
                    $sub->where('name', 'like', "%{$search}%")
                        ->orWhere('sku', 'like', "%{$search}%");
                });
            })
            ->when($filters['status'], function ($query, string $status): void {
                $query->where('status', $status);
            })
            ->orderBy($sortBy, $sortDirection)
            ->paginate($filters['per_page'])
            ->withQueryString();

        return Inertia::render('Products/Index', [
            'items' => $items,
            'filters' => $filters,
        ]);
    }
}
```

---

## Etapa 2: Componentes shadcn-vue Necessários

Antes de criar a tela Vue, confirme a presença dos seguintes componentes em `resources/js/components/ui/`:

1. `table` (`Table`, `TableHeader`, `TableBody`, `TableRow`, `TableHead`, `TableCell`)
2. `input` (`Input`)
3. `button` (`Button`)
4. `badge` (`Badge`)
5. `select` (`Select`, `SelectTrigger`, `SelectValue`, `SelectContent`, `SelectItem`)
6. `dropdown-menu` (`DropdownMenu`, `DropdownMenuTrigger`, `DropdownMenuContent`, `DropdownMenuItem`, `DropdownMenuSeparator`)

Caso algum componente esteja ausente, execute a skill `@add-shadcn-component`:
```bash
npx shadcn-vue@latest add table dropdown-menu select badge button input --yes
```

---

## Etapa 3: Definições de Tipagem TypeScript

Crie ou atualize o arquivo de tipos em `resources/js/types/{entities}.d.ts`:

```typescript
export interface PaginatedResponse<T> {
  data: T[];
  current_page: number;
  last_page: number;
  per_page: number;
  total: number;
  from: number | null;
  to: number | null;
  links: {
    url: string | null;
    label: string;
    active: boolean;
  }[];
}

export interface TableFilters {
  search: string;
  status: string;
  sort: string;
  direction: 'asc' | 'desc';
  per_page: number;
}

export interface ProductItem {
  id: number;
  sku: string;
  name: string;
  price: number;
  status: 'draft' | 'active' | 'archived';
  category?: {
    id: number;
    name: string;
  } | null;
  created_at: string;
}
```

---

## Etapa 4: Implementação da View de Tabela (`Index.vue`)

Crie a página em `resources/js/pages/{Entities}/Index.vue` seguindo a arquitetura abaixo:

```vue
<script setup lang="ts">
import { ref, watch } from 'vue';
import { Head, Link, router } from '@inertiajs/vue3';
import {
  Search,
  Plus,
  ArrowUpDown,
  ArrowUp,
  ArrowDown,
  MoreHorizontal,
  Pencil,
  Trash2,
  XCircle,
  FolderOpen,
  FilterX,
} from 'lucide-vue-next';

import { ProductItem, PaginatedResponse, TableFilters } from '@/types/products';
import { index, create, edit, destroy } from '@/routes/products';

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

const props = defineProps<{
  items: PaginatedResponse<ProductItem>;
  filters: TableFilters;
}>();

// Estado reativo local inicializado com os props
const search = ref(props.filters.search ?? '');
const status = ref(props.filters.status ?? '');
const sortField = ref(props.filters.sort ?? 'id');
const sortDirection = ref<'asc' | 'desc'>(props.filters.direction ?? 'desc');

// Disparo sincronizado com o Inertia preservando scroll e cache parcial
function applyFilters() {
  router.get(
    index().url,
    {
      search: search.value || undefined,
      status: status.value || undefined,
      sort: sortField.value,
      direction: sortDirection.value,
      per_page: props.filters.per_page,
    },
    {
      preserveState: true,
      preserveScroll: true,
      replace: true,
      only: ['items', 'filters'],
    }
  );
}

// Debounce para busca textual
let debounceTimeout: ReturnType<typeof setTimeout>;
watch(search, () => {
  clearTimeout(debounceTimeout);
  debounceTimeout = setTimeout(() => {
    applyFilters();
  }, 350);
});

// Atualização imediata para filtros categóricos
watch(status, () => {
  applyFilters();
});

// Alternância de ordenação por coluna
function toggleSort(field: string) {
  if (sortField.value === field) {
    sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc';
  } else {
    sortField.value = field;
    sortDirection.value = 'asc';
  }
  applyFilters();
}

// Limpeza de todos os filtros ativos
function clearFilters() {
  search.value = '';
  status.value = '';
  sortField.value = 'id';
  sortDirection.value = 'desc';
  applyFilters();
}

// Exclusão com confirmação acessível
function confirmDelete(item: ProductItem) {
  if (confirm(`Deseja realmente excluir "${item.name}"?`)) {
    router.delete(destroy({ product: item.id }).url, {
      preserveScroll: true,
    });
  }
}

// Helpers visuais de badge
function getStatusBadgeVariant(statusValue: ProductItem['status']) {
  switch (statusValue) {
    case 'active':
      return 'default';
    case 'draft':
      return 'secondary';
    case 'archived':
      return 'outline';
    default:
      return 'secondary';
  }
}

// Formatador de moeda
function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(amount);
}
</script>

<template>
  <Head title="Produtos" />

  <div class="space-y-6 p-6">
    <!-- Cabeçalho de Ações Principais -->
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-bold tracking-tight">Produtos</h1>
        <p class="text-sm text-muted-foreground">
          Gerencie o catálogo completo de produtos e estoques.
        </p>
      </div>

      <Button as-child>
        <Link :href="create().url">
          <Plus class="mr-2 h-4 w-4" /> Novo Produto
        </Link>
      </Button>
    </div>

    <!-- Barra de Ferramentas: Busca & Filtros -->
    <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
      <div class="flex flex-1 flex-col gap-3 sm:flex-row sm:items-center">
        <!-- Campo de Busca -->
        <div class="relative w-full max-w-sm">
          <Search class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            v-model="search"
            placeholder="Buscar por nome ou SKU..."
            class="pl-9 pr-9"
          />
          <button
            v-if="search"
            type="button"
            aria-label="Limpar busca"
            class="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
            @click="search = ''"
          >
            <XCircle class="h-4 w-4" />
          </button>
        </div>

        <!-- Seletor de Status -->
        <div class="w-full sm:w-[180px]">
          <Select v-model="status">
            <SelectTrigger>
              <SelectValue placeholder="Todos os status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="">Todos os status</SelectItem>
              <SelectItem value="active">Ativo</SelectItem>
              <SelectItem value="draft">Rascunho</SelectItem>
              <SelectItem value="archived">Arquivado</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <!-- Botão Limpar Filtros -->
        <Button
          v-if="search || status"
          variant="ghost"
          size="sm"
          class="h-9 px-2 text-muted-foreground hover:text-foreground"
          @click="clearFilters"
        >
          <FilterX class="mr-2 h-4 w-4" /> Limpar filtros
        </Button>
      </div>
    </div>

    <!-- Container da Tabela com Borda e Card -->
    <div class="rounded-lg border bg-card shadow-sm">
      <Table>
        <TableHeader>
          <TableRow>
            <!-- Coluna ID com ordenação -->
            <TableHead class="w-[80px]">
              <button
                type="button"
                class="flex items-center gap-1 font-semibold hover:text-foreground"
                @click="toggleSort('id')"
              >
                ID
                <ArrowUp v-if="sortField === 'id' && sortDirection === 'asc'" class="h-3.5 w-3.5" />
                <ArrowDown v-else-if="sortField === 'id' && sortDirection === 'desc'" class="h-3.5 w-3.5" />
                <ArrowUpDown v-else class="h-3.5 w-3.5 text-muted-foreground/60" />
              </button>
            </TableHead>

            <!-- Coluna Nome com ordenação -->
            <TableHead>
              <button
                type="button"
                class="flex items-center gap-1 font-semibold hover:text-foreground"
                @click="toggleSort('name')"
              >
                Produto
                <ArrowUp v-if="sortField === 'name' && sortDirection === 'asc'" class="h-3.5 w-3.5" />
                <ArrowDown v-else-if="sortField === 'name' && sortDirection === 'desc'" class="h-3.5 w-3.5" />
                <ArrowUpDown v-else class="h-3.5 w-3.5 text-muted-foreground/60" />
              </button>
            </TableHead>

            <TableHead class="hidden md:table-cell">Categoria</TableHead>

            <TableHead class="text-right">
              <button
                type="button"
                class="ml-auto flex items-center gap-1 font-semibold hover:text-foreground"
                @click="toggleSort('price')"
              >
                Preço
                <ArrowUp v-if="sortField === 'price' && sortDirection === 'asc'" class="h-3.5 w-3.5" />
                <ArrowDown v-else-if="sortField === 'price' && sortDirection === 'desc'" class="h-3.5 w-3.5" />
                <ArrowUpDown v-else class="h-3.5 w-3.5 text-muted-foreground/60" />
              </button>
            </TableHead>

            <TableHead class="w-[120px]">Status</TableHead>
            <TableHead class="w-[70px] text-right">Ações</TableHead>
          </TableRow>
        </TableHeader>

        <TableBody>
          <TableRow
            v-for="item in items.data"
            :key="item.id"
            class="transition-colors hover:bg-muted/50"
          >
            <!-- ID Tabular -->
            <TableCell class="font-mono text-xs tabular-nums text-muted-foreground">
              #{{ item.id }}
            </TableCell>

            <!-- Identificação do Produto -->
            <TableCell>
              <div class="font-medium text-foreground">{{ item.name }}</div>
              <div class="font-mono text-xs text-muted-foreground">SKU: {{ item.sku }}</div>
            </TableCell>

            <!-- Categoria Eager Loaded -->
            <TableCell class="hidden text-sm text-muted-foreground md:table-cell">
              {{ item.category?.name ?? '—' }}
            </TableCell>

            <!-- Preço com Alinhamento Tabular -->
            <TableCell class="text-right font-mono text-sm tabular-nums font-medium">
              {{ formatCurrency(item.price) }}
            </TableCell>

            <!-- Status Semântico -->
            <TableCell>
              <Badge :variant="getStatusBadgeVariant(item.status)" class="capitalize">
                {{ item.status }}
              </Badge>
            </TableCell>

            <!-- Dropdown de Ações por Linha -->
            <TableCell class="text-right">
              <DropdownMenu>
                <DropdownMenuTrigger as-child>
                  <Button
                    variant="ghost"
                    size="icon"
                    class="h-8 w-8 p-0"
                    :aria-label="`Ações para ${item.name}`"
                  >
                    <MoreHorizontal class="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem as-child>
                    <Link
                      :href="edit({ product: item.id }).url"
                      class="flex cursor-pointer items-center gap-2"
                    >
                      <Pencil class="h-4 w-4" /> Editar
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem
                    class="flex cursor-pointer items-center gap-2 text-destructive focus:text-destructive"
                    @click="confirmDelete(item)"
                  >
                    <Trash2 class="h-4 w-4" /> Excluir
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </TableCell>
          </TableRow>

          <!-- Empty State (Sem Resultados) -->
          <TableRow v-if="items.data.length === 0">
            <TableCell colspan="6" class="h-64 text-center">
              <div class="flex flex-col items-center justify-center space-y-3">
                <div class="rounded-full bg-muted p-3">
                  <FolderOpen class="h-8 w-8 text-muted-foreground" />
                </div>
                <div class="space-y-1">
                  <p class="text-base font-semibold">Nenhum registro encontrado</p>
                  <p class="text-sm text-muted-foreground max-w-sm">
                    Não encontramos resultados com os filtros atuais. Tente ajustar os termos de pesquisa.
                  </p>
                </div>
                <Button
                  v-if="search || status"
                  variant="outline"
                  size="sm"
                  class="mt-2"
                  @click="clearFilters"
                >
                  Limpar filtros aplicados
                </Button>
              </div>
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>

    <!-- Barra de Rodapé: Contadores e Paginação -->
    <div
      v-if="items.total > 0"
      class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between"
    >
      <p class="text-xs text-muted-foreground font-mono tabular-nums">
        Exibindo <span class="font-medium text-foreground">{{ items.from ?? 0 }}</span> a
        <span class="font-medium text-foreground">{{ items.to ?? 0 }}</span> de
        <span class="font-medium text-foreground">{{ items.total }}</span> registros
      </p>

      <!-- Paginação com Botões shadcn -->
      <div v-if="items.last_page > 1" class="flex items-center gap-1.5">
        <Button
          v-for="(link, index) in items.links"
          :key="index"
          :variant="link.active ? 'default' : 'outline'"
          size="sm"
          :disabled="!link.url"
          class="h-8 min-w-[32px] px-2 text-xs"
          as-child
        >
          <Link
            v-if="link.url"
            :href="link.url"
            preserve-scroll
            preserve-state
            v-html="link.label"
          />
          <span v-else v-html="link.label" />
        </Button>
      </div>
    </div>
  </div>
</template>
```

---

## Etapa 5: Checklist do Padrão Impeccable (UI Craft)

Antes de considerar a tabela finalizada, audite os seguintes quesitos visuais e ergonômicos:

1. **Alinhamento Numérico:**
   - [ ] Todos os valores numéricos, quantitativos, monetários e identificadores usam `font-mono tabular-nums text-right` (ou `text-left` para IDs).
2. **Prevenção de Quebra Desordenada de Layout:**
   - [ ] Nomes ou textos variáveis têm classe de contenção ou truncamento quando necessário (`max-w-[260px] truncate`).
3. **Ergonomia dos Filtros:**
   - [ ] A busca conta com botão de limpeza rápida (`XCircle`) visível somente quando há conteúdo digitado.
   - [ ] O botão "Limpar filtros" só é exibido se houver filtros ativos.
   - [ ] Parâmetros vazios são enviados como `undefined` no objeto do `router.get()` para que o Inertia remova as chaves da URL (mantendo a URL limpa).
4. **Preservação de Scroll e Estado:**
   - [ ] As transições de filtro e paginação utilizam `preserveScroll: true` e `preserveState: true`.
   - [ ] O parâmetro `only: ['items', 'filters']` do Inertia é utilizado para evitar reprocessar props globais desnecessárias da sessão.
5. **Acessibilidade:**
   - [ ] Todos os botões contendo apenas ícones possuem atributo `aria-label` explícito.
   - [ ] Os cabeçalhos com ordenação indicam visualmente a direção ativa através de ícones distintos (`ArrowUp`, `ArrowDown`, `ArrowUpDown`).