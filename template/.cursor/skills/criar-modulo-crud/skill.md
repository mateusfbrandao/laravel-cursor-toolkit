---
name: criar-modulo-crud
description: Executa o fluxo completo de criação de um módulo/recurso CRUD ponta a ponta (Migration, Model, DTOs, Actions, Form Requests, Policy, Controller, Wayfinder Routes, Telas Vue com shadcn-vue e Testes Pest).
---

# Skill: Criação de Módulo CRUD Completo

Esta skill define o fluxo sequencial obrigatório para a criação de qualquer módulo ou recurso em aplicações que seguem o padrão arquitetural do Toolkit.

Siga estritamente a sequência de etapas abaixo. Não pule fases nem inverta a ordem de implementação.

---

## Convenções de Nomenclatura do Módulo
Para este runbook, assuma a entidade genérica `{Entity}` (ex.: `Product`, `Customer`, `Order`):
- **Tabela / Colunas:** `snake_case` no plural (ex.: `products`, `unit_price`).
- **Classes PHP / Interfaces TS / Componentes Vue:** `PascalCase` no singular (ex.: `Product`, `CreateProductAction`, `ProductIndex.vue`).
- **Rotas / URLs:** `kebab-case` ou `snake_case` no plural (ex.: `/products`, `products.index`).
- **Diretórios de Página Vue:** `resources/js/pages/{Entities}/` (ex.: `resources/js/pages/Products/`).

---

## Etapa 1: Banco de Dados & Model

### 1.1 Migration (`database/migrations/YYYY_MM_DD_create_{entities}_table.php`)
- Crie chaves primárias e estrangeiras explícitas com integridade referencial.
- Adicione índices para colunas usadas frequentemente em filtros, buscas ou ordenações.
- Defina valores padrão sensatos quando aplicável.

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('{entities}', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->nullable()->constrained()->cascadeOnDelete();
            $table->string('name')->index();
            $table->string('slug')->unique();
            $table->text('description')->nullable();
            $table->string('status')->default('draft')->index();
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('{entities}');
    }
};
```

### 1.2 Model (`app/Models/{Entity}.php`)
- Declare `declare(strict_types=1);`.
- Use obrigatoriamente o método `protected function casts(): array` (NUNCA utilize o atributo protegido `$casts = [...]`).
- Declare tipagem explícita em todos os relacionamentos Eloquent (`BelongsTo`, `HasMany`, etc.).

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

final class {Entity} extends Model
{
    use HasFactory;
    use SoftDeletes;

    protected $guarded = ['id', 'created_at', 'updated_at'];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'id' => 'integer',
            'tenant_id' => 'integer',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
            'deleted_at' => 'datetime',
        ];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }
}
```

---

## Etapa 2: DTOs & Actions de Negócio

### 2.1 DTO de Entrada (`app/DTOs/{Entity}/{Entity}Data.php`)
- DTOs devem ser classes imutáveis (`final readonly class`).
- Implemente o construtor tipado e um método estático `fromRequest()` para encapsular a extração dos dados validados.

```php
<?php

declare(strict_types=1);

namespace App\DTOs\{Entity};

use App\Http\Requests\{Entity}\Store{Entity}Request;
use App\Http\Requests\{Entity}\Update{Entity}Request;

final readonly class {Entity}Data
{
    public function __construct(
        public string $name,
        public ?string $description,
        public string $status,
    ) {}

    public static function fromStoreRequest(Store{Entity}Request $request): self
    {
        /** @var array{name: string, description: ?string, status: string} $validated */
        $validated = $request->validated();

        return new self(
            name: $validated['name'],
            description: $validated['description'] ?? null,
            status: $validated['status'] ?? 'draft',
        );
    }

    public static function fromUpdateRequest(Update{Entity}Request $request): self
    {
        /** @var array{name: string, description: ?string, status: string} $validated */
        $validated = $request->validated();

        return new self(
            name: $validated['name'],
            description: $validated['description'] ?? null,
            status: $validated['status'],
        );
    }
}
```

### 2.2 Actions (`app/Actions/{Entity}/...`)
- Uma classe por mutação com responsabilidade única: `Create{Entity}Action`, `Update{Entity}Action`, `Delete{Entity}Action`.
- Implemente o método invocável `public function __invoke(...)`.
- Mutações múltiplas ou com disparo de eventos devem ser encapsuladas em `DB::transaction(...)`.

```php
<?php

declare(strict_types=1);

namespace App\Actions\{Entity};

use App\DTOs\{Entity}\{Entity}Data;
use App\Models\{Entity};
use Illuminate\Support\Facades\DB;

final class Create{Entity}Action
{
    public function __invoke({Entity}Data $data): {Entity}
    {
        return DB::transaction(function () use ($data): {Entity} {
            return {Entity}::create([
                'name' => $data->name,
                'slug' => str($data->name)->slug()->value(),
                'description' => $data->description,
                'status' => $data->status,
            ]);
        });
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Actions\{Entity};

use App\DTOs\{Entity}\{Entity}Data;
use App\Models\{Entity};
use Illuminate\Support\Facades\DB;

final class Update{Entity}Action
{
    public function __invoke({Entity} ${entityLower}, {Entity}Data $data): {Entity}
    {
        return DB::transaction(function () use (${entityLower}, $data): {Entity} {
            ${entityLower}->update([
                'name' => $data->name,
                'slug' => str($data->name)->slug()->value(),
                'description' => $data->description,
                'status' => $data->status,
            ]);

            return ${entityLower}->fresh();
        });
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Actions\{Entity};

use App\Models\{Entity};
use Illuminate\Support\Facades\DB;

final class Delete{Entity}Action
{
    public function __invoke({Entity} ${entityLower}): bool
    {
        return DB::transaction(function () use (${entityLower}): bool {
            return (bool) ${entityLower}->delete();
        });
    }
}
```

---

## Etapa 3: Validação, Autorização & Controller

### 3.1 Form Requests (`app/Http/Requests/{Entity}/...`)
- Validações devem residir em classes dedicadas.
- O método `authorize(): bool` deve delegar para a Policy do Model.

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests\{Entity};

use App\Models\{Entity};
use Illuminate\Foundation\Http\FormRequest;

final class Store{Entity}Request extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->can('create', {Entity}::class) ?? false;
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'status' => ['nullable', 'string', 'in:draft,active,archived'],
        ];
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests\{Entity};

use App\Models\{Entity};
use Illuminate\Foundation\Http\FormRequest;

final class Update{Entity}Request extends FormRequest
{
    public function authorize(): bool
    {
        /** @var {Entity} ${entityLower} */
        ${entityLower} = $this->route('{entityLower}');

        return $this->user()?->can('update', ${entityLower}) ?? false;
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'status' => ['required', 'string', 'in:draft,active,archived'],
        ];
    }
}
```

### 3.2 Policy (`app/Policies/{Entity}Policy.php`)
- Cubra os métodos padrão: `viewAny`, `view`, `create`, `update`, `delete`, `restore`, `forceDelete`.

```php
<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\{Entity};
use App\Models\User;

final class {Entity}Policy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, {Entity} ${entityLower}): bool
    {
        return true;
    }

    public function create(User $user): bool
    {
        return true;
    }

    public function update(User $user, {Entity} ${entityLower}): bool
    {
        return true;
    }

    public function delete(User $user, {Entity} ${entityLower}): bool
    {
        return true;
    }
}
```

### 3.3 Slim Controller (`app/Http/Controllers/{Entity}Controller.php`)
- Os métodos devem ter no máximo 5–10 linhas.
- Injete as Actions via injeção de dependência.
- Retorne respostas Inertia com props tipadas e redirects limpos.

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Actions\{Entity}\Create{Entity}Action;
use App\Actions\{Entity}\Delete{Entity}Action;
use App\Actions\{Entity}\Update{Entity}Action;
use App\DTOs\{Entity}\{Entity}Data;
use App\Http\Requests\{Entity}\Store{Entity}Request;
use App\Http\Requests\{Entity}\Update{Entity}Request;
use App\Models\{Entity};
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

final class {Entity}Controller extends Controller
{
    public function index(Request $request): Response
    {
        $this->authorize('viewAny', {Entity}::class);

        $filters = $request->only(['search', 'status']);

        $items = {Entity}::query()
            ->when($request->input('search'), function ($query, string $search): void {
                $query->where('name', 'like', "%{$search}%");
            })
            ->when($request->input('status'), function ($query, string $status): void {
                $query->where('status', $status);
            })
            ->latest('id')
            ->paginate(15)
            ->withQueryString();

        return Inertia::render('{Entities}/Index', [
            'items' => $items,
            'filters' => $filters,
        ]);
    }

    public function create(): Response
    {
        $this->authorize('create', {Entity}::class);

        return Inertia::render('{Entities}/Create');
    }

    public function store(Store{Entity}Request $request, Create{Entity}Action $action): RedirectResponse
    {
        $action({Entity}Data::fromStoreRequest($request));

        return redirect()->route('{entities}.index')
            ->with('success', '{Entity} criada com sucesso.');
    }

    public function edit({Entity} ${entityLower}): Response
    {
        $this->authorize('update', ${entityLower});

        return Inertia::render('{Entities}/Edit', [
            'item' => ${entityLower},
        ]);
    }

    public function update(
        Update{Entity}Request $request,
        {Entity} ${entityLower},
        Update{Entity}Action $action
    ): RedirectResponse {
        $action(${entityLower}, {Entity}Data::fromUpdateRequest($request));

        return redirect()->route('{entities}.index')
            ->with('success', '{Entity} atualizada com sucesso.');
    }

    public function destroy({Entity} ${entityLower}, Delete{Entity}Action $action): RedirectResponse
    {
        $this->authorize('delete', ${entityLower});

        $action(${entityLower});

        return redirect()->route('{entities}.index')
            ->with('success', '{Entity} removida com sucesso.');
    }
}
```

---

## Etapa 4: Rotas & Wayfinder

### 4.1 Registro de Rotas (`routes/web.php`)
```php
use App\Http\Controllers\{Entity}Controller;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth', 'verified'])->group(function (): void {
    Route::resource('{entities}', {Entity}Controller::class);
});
```

### 4.2 Geração dos Tipos de Rotas Wayfinder
Execute no terminal:
```bash
php artisan wayfinder:generate
```

---

## Etapa 5: Frontend Vue 3 + shadcn-vue

### 5.1 Tipos Compartilhados (`resources/js/types/{entities}.d.ts`)
```typescript
export interface {Entity}Item {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  status: 'draft' | 'active' | 'archived';
  created_at: string;
  updated_at: string;
}

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
```

### 5.2 Listagem (`resources/js/pages/{Entities}/Index.vue`)
- Utiliza componentes de `@/components/ui/` (`Table`, `Button`, `Input`, `Badge`, `DropdownMenu`).
- Roteamento tipado com Laravel Wayfinder importado de `@/routes/{entities}`.
- Filtros reativos com debounce, preservando estado e scroll do Inertia.

```vue
<script setup lang="ts">
import { ref, watch } from 'vue';
import { Head, Link, router } from '@inertiajs/vue3';
import { Plus, Search, MoreHorizontal, Pencil, Trash2, FolderOpen } from 'lucide-vue-next';
import { {Entity}Item, PaginatedResponse } from '@/types/{entities}';
import { index, create, edit, destroy } from '@/routes/{entities}';

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
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

const props = defineProps<{
  items: PaginatedResponse<{Entity}Item>;
  filters: { search?: string; status?: string };
}>();

const search = ref(props.filters.search ?? '');

let searchDebounce: ReturnType<typeof setTimeout>;
watch(search, (value) => {
  clearTimeout(searchDebounce);
  searchDebounce = setTimeout(() => {
    router.get(
      index().url,
      { search: value || undefined },
      { preserveState: true, preserveScroll: true, replace: true, only: ['items', 'filters'] }
    );
  }, 350);
});

function deleteItem(item: {Entity}Item) {
  if (confirm(`Deseja realmente remover o item "${item.name}"?`)) {
    router.delete(destroy({ {entityLower}: item.id }).url, {
      preserveScroll: true,
    });
  }
}
</script>

<template>
  <Head title="{Entities}" />

  <div class="space-y-6 p-6">
    <!-- Header -->
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-bold tracking-tight">{Entities}</h1>
        <p class="text-sm text-muted-foreground">Gerencie todos os registros cadastrados no sistema.</p>
      </div>
      <Button as-child>
        <Link :href="create().url">
          <Plus class="mr-2 h-4 w-4" /> Novo Registro
        </Link>
      </Button>
    </div>

    <!-- Filtros -->
    <div class="flex items-center gap-4">
      <div class="relative w-full max-w-sm">
        <Search class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          v-model="search"
          placeholder="Buscar por nome..."
          class="pl-9"
        />
      </div>
    </div>

    <!-- Tabela -->
    <div class="rounded-md border bg-card">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead class="w-[80px]">ID</TableHead>
            <TableHead>Nome</TableHead>
            <TableHead>Status</TableHead>
            <TableHead class="text-right">Ações</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow v-for="item in items.data" :key="item.id">
            <TableCell class="font-mono text-xs tabular-nums text-muted-foreground">
              #{{ item.id }}
            </TableCell>
            <TableCell class="font-medium">
              {{ item.name }}
            </TableCell>
            <TableCell>
              <Badge variant="outline">{{ item.status }}</Badge>
            </TableCell>
            <TableCell class="text-right">
              <DropdownMenu>
                <DropdownMenuTrigger as-child>
                  <Button variant="ghost" size="icon" class="h-8 w-8 p-0" aria-label="Ações">
                    <MoreHorizontal class="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem as-child>
                    <Link :href="edit({ {entityLower}: item.id }).url" class="flex items-center gap-2 cursor-pointer">
                      <Pencil class="h-4 w-4" /> Editar
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuItem @click="deleteItem(item)" class="flex items-center gap-2 text-destructive cursor-pointer">
                    <Trash2 class="h-4 w-4" /> Excluir
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </TableCell>
          </TableRow>

          <!-- Empty State -->
          <TableRow v-if="items.data.length === 0">
            <TableCell colspan="4" class="h-48 text-center">
              <div class="flex flex-col items-center justify-center space-y-2">
                <FolderOpen class="h-10 w-10 text-muted-foreground" />
                <p class="text-base font-semibold">Nenhum registro encontrado</p>
                <p class="text-sm text-muted-foreground">Tente ajustar a busca ou adicione um novo registro.</p>
              </div>
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>

    <!-- Paginação -->
    <div v-if="items.last_page > 1" class="flex items-center justify-between">
      <span class="text-xs text-muted-foreground tabular-nums font-mono">
        Exibindo {{ items.from }} a {{ items.to }} de {{ items.total }}
      </span>
      <div class="flex gap-2">
        <Button
          v-for="(link, index) in items.links"
          :key="index"
          variant="outline"
          size="sm"
          :disabled="!link.url || link.active"
          as-child
        >
          <Link v-if="link.url" :href="link.url" preserve-scroll v-html="link.label" />
          <span v-else v-html="link.label" />
        </Button>
      </div>
    </div>
  </div>
</template>
```

### 5.3 Formulário de Criação (`resources/js/pages/{Entities}/Create.vue`)
- Utiliza o helper `useForm` do Inertia.js.
- Microinterações completas: botão de submit com indicador animado `Loader2` durante o processamento (`form.processing`).
- Roteamento tipado com Wayfinder.

```vue
<script setup lang="ts">
import { Head, Link, useForm } from '@inertiajs/vue3';
import { ArrowLeft, Loader2 } from 'lucide-vue-next';
import { index, store } from '@/routes/{entities}';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '@/components/ui/card';

const form = useForm({
  name: '',
  description: '',
  status: 'draft',
});

function submit() {
  form.post(store().url);
}
</script>

<template>
  <Head title="Novo Registro" />

  <div class="max-w-2xl mx-auto p-6 space-y-6">
    <Button variant="ghost" size="sm" as-child>
      <Link :href="index().url" class="inline-flex items-center gap-2">
        <ArrowLeft class="h-4 w-4" /> Voltar para a lista
      </Link>
    </Button>

    <Card>
      <form @submit.prevent="submit">
        <CardHeader>
          <CardTitle>Criar Novo Registro</CardTitle>
          <CardDescription>Preencha os dados abaixo para cadastrar o item.</CardDescription>
        </CardHeader>
        <CardContent class="space-y-4">
          <div class="space-y-2">
            <Label for="name">Nome *</Label>
            <Input
              id="name"
              v-model="form.name"
              :disabled="form.processing"
              :class="{ 'border-destructive focus-visible:ring-destructive': form.errors.name }"
              placeholder="Ex.: Nome do recurso"
            />
            <p v-if="form.errors.name" class="text-xs font-medium text-destructive">
              {{ form.errors.name }}
            </p>
          </div>

          <div class="space-y-2">
            <Label for="description">Descrição</Label>
            <Input
              id="description"
              v-model="form.description"
              :disabled="form.processing"
              placeholder="Descrição opcional"
            />
            <p v-if="form.errors.description" class="text-xs font-medium text-destructive">
              {{ form.errors.description }}
            </p>
          </div>
        </CardContent>
        <CardFooter class="flex justify-end gap-2">
          <Button variant="outline" as-child :disabled="form.processing">
            <Link :href="index().url">Cancelar</Link>
          </Button>
          <Button type="submit" :disabled="form.processing">
            <Loader2 v-if="form.processing" class="mr-2 h-4 w-4 animate-spin" />
            Salvar
          </Button>
        </CardFooter>
      </form>
    </Card>
  </div>
</template>
```

---

## Etapa 6: Testes Automatizados (Pest PHP)

### 6.1 Teste de Feature (`tests/Feature/{Entity}Test.php`)
- Utiliza a sintaxe expressiva do Pest PHP.
- Valida autorização, criação, validação de inputs e deleção.

```php
<?php

declare(strict_types=1);

use App\Models\{Entity};
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    $this->user = User::factory()->create();
});

test('convidado nao autenticado eh redirecionado ao tentar acessar index', function (): void {
    $this->get(route('{entities}.index'))
        ->assertRedirect(route('login'));
});

test('usuario autenticado pode visualizar lista de registros', function (): void {
    {Entity}::factory()->count(3)->create();

    $this->actingAs($this->user)
        ->get(route('{entities}.index'))
        ->assertOk()
        ->assertInertia(fn (Assert $page) => $page
            ->component('{Entities}/Index')
            ->has('items.data', 3)
            ->has('filters')
        );
});

test('usuario pode cadastrar um novo registro com dados validos', function (): void {
    $payload = [
        'name' => 'Novo Item de Teste',
        'description' => 'Descricao detalhada',
        'status' => 'draft',
    ];

    $this->actingAs($this->user)
        ->post(route('{entities}.store'), $payload)
        ->assertRedirect(route('{entities}.index'));

    $this->assertDatabaseHas('{entities}', [
        'name' => 'Novo Item de Teste',
        'status' => 'draft',
    ]);
});

test('falha na validacao ao tentar criar registro sem nome', function (): void {
    $this->actingAs($this->user)
        ->post(route('{entities}.store'), ['name' => ''])
        ->assertSessionHasErrors(['name']);
});

test('usuario pode deletar um registro existente', function (): void {
    ${entityLower} = {Entity}::factory()->create();

    $this->actingAs($this->user)
        ->delete(route('{entities}.destroy', ${entityLower}))
        ->assertRedirect(route('{entities}.index'));

    $this->assertSoftDeleted(${entityLower});
});
```

---

## Etapa 7: Verificação de Qualidade e Formatação

Após concluir a escrita dos arquivos, execute imediatamente os analisadores estáticos e formatadores:

```bash
# 1. Laravel Pint
./vendor/bin/pint app/Http/Controllers/{Entity}Controller.php app/Actions/{Entity}/ app/DTOs/{Entity}/ app/Models/{Entity}.php app/Http/Requests/{Entity}/ tests/Feature/{Entity}Test.php

# 2. Larastan (PHPStan)
./vendor/bin/phpstan analyse app/Http/Controllers/{Entity}Controller.php app/Actions/{Entity}/ app/DTOs/{Entity}/ app/Models/{Entity}.php app/Http/Requests/{Entity}/ tests/Feature/{Entity}Test.php --no-progress

# 3. Testes Pest
./vendor/bin/pest tests/Feature/{Entity}Test.php
```