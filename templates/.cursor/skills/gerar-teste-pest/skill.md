## name: gerar-teste-pest

description: Gera suítes de testes de integração e feature completas com Pest PHP no ecossistema Laravel + Inertia.js, cobrindo autenticação, autorização via Policies, validação estrita de Form Requests, integridade de mutações de banco de dados e contratos de visualização com AssertableInertia.

# Skill: Geração de Testes de Feature (Pest PHP + Inertia)

Esta skill estabelece o padrão arquitetural e a matriz de cobertura obrigatória para a criação de testes de feature automatizados utilizando **Pest PHP** no ecossistema **Laravel + Inertia.js**.

Siga este procedimento para garantir que cada novo endpoint ou fluxo de telas seja testado contra regressões em todas as camadas (acesso, regras de autorização, validação, persistência e contratos de dados retornados ao frontend).

---

## Etapa 1: A Matriz dos 5 Pilares de Cobertura

Todo módulo CRUD ou endpoint interativo deve conter, no mínimo, a cobertura dos 5 pilares fundamentais:

| Pilar | Objetivo do Teste | Asserções Chave |
| :--- | :--- | :--- |
| **1. Autenticação (Guests)** | Bloquear visitantes não autenticados | `assertRedirect(route('login'))` ou `assertGuest()` |
| **2. Autorização (Policies)** | Bloquear usuários sem permissão (ou de outro tenant) | `assertForbidden()` (HTTP 403) |
| **3. Contratos de View Inertia** | Garantir que o componente Vue correto e props esperadas cheguem ao frontend | `assertInertia(fn (Assert $page) => ...)` |
| **4. Validação (Form Requests)** | Rejeitar payloads malformados ou dados vazios | `assertSessionHasErrors(['field_name'])` |
| **5. Persistência & Efeitos Colaterais** | Confirmar mutações no banco de dados e mensagens flash | `assertDatabaseHas()`, `assertSoftDeleted()`, `assertSessionHas()` |

---

## Etapa 2: Estrutura Base do Arquivo de Teste

Crie o arquivo em `tests/Feature/{Domain}/{Entity}Test.php` seguindo a estrutura inicial abaixo:

```php
<?php

declare(strict_types=1);

use App\Models\Product;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    $this->tenant = Tenant::factory()->create();
    
    $this->user = User::factory()->create([
        'tenant_id' => $this->tenant->id,
    ]);
});
```

---

## Etapa 3: Implementação Completa da Suíte de Testes

Abaixo encontra-se a suíte completa de referência para uma entidade (`Product`):

```php
<?php

declare(strict_types=1);

use App\Models\Category;
use App\Models\Product;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    $this->tenant = Tenant::factory()->create();

    $this->user = User::factory()->create([
        'tenant_id' => $this->tenant->id,
    ]);
});

/*
|--------------------------------------------------------------------------
| 1. Testes de Autenticação (Guest Protection)
|--------------------------------------------------------------------------
*/

test('visitantes nao autenticados sao redirecionados ao tentar acessar a listagem', function (): void {
    $this->get(route('products.index'))
        ->assertRedirect(route('login'));
});

test('visitantes nao autenticados nao podem enviar formulario de criacao', function (): void {
    $this->post(route('products.store'), [
        'name' => 'Produto Não Autorizado',
    ])->assertRedirect(route('login'));
});

/*
|--------------------------------------------------------------------------
| 2. Testes de Autorização (Policies & Tenant Isolation)
|--------------------------------------------------------------------------
*/

test('usuario nao pode visualizar nem editar produtos de outro tenant', function (): void {
    $outroTenant = Tenant::factory()->create();
    $produtoAlheio = Product::factory()->create([
        'tenant_id' => $outroTenant->id,
    ]);

    $this->actingAs($this->user)
        ->get(route('products.edit', $produtoAlheio))
        ->assertForbidden();
});

test('usuario sem permissao nao pode excluir um produto', function (): void {
    $produto = Product::factory()->create([
        'tenant_id' => $this->tenant->id,
    ]);

    $usuarioSemPermissao = User::factory()->create([
        'tenant_id' => $this->tenant->id,
        // Caso use roles/permissions: 'role' => 'viewer'
    ]);

    $this->actingAs($usuarioSemPermissao)
        ->delete(route('products.destroy', $produto))
        ->assertForbidden();
});

/*
|--------------------------------------------------------------------------
| 3. Testes de Contrato Inertia (Telas de Listagem & Edição)
|--------------------------------------------------------------------------
*/

test('usuario autenticado pode visualizar listagem com dados paginados e filtros', function (): void {
    $categoria = Category::factory()->create();

    Product::factory()->count(5)->create([
        'tenant_id' => $this->tenant->id,
        'category_id' => $categoria->id,
    ]);

    $this->actingAs($this->user)
        ->get(route('products.index', ['search' => '', 'status' => 'active']))
        ->assertOk()
        ->assertInertia(fn (Assert $page) => $page
            ->component('Products/Index')
            ->has('items.data', 5)
            ->has('items.data.0', fn (Assert $item) => $item
                ->has('id')
                ->has('name')
                ->has('sku')
                ->has('price')
                ->has('status')
                ->has('category')
                ->etc()
            )
            ->has('filters', fn (Assert $filters) => $filters
                ->where('status', 'active')
                ->etc()
            )
        );
});

test('listagem aplica busca textual por nome ou sku com sucesso', function (): void {
    Product::factory()->create([
        'tenant_id' => $this->tenant->id,
        'name' => 'Teclado Mecânico Pro',
        'sku' => 'TEC-001',
    ]);

    Product::factory()->create([
        'tenant_id' => $this->tenant->id,
        'name' => 'Mouse Sem Fio Ultra',
        'sku' => 'MOU-002',
    ]);

    $this->actingAs($this->user)
        ->get(route('products.index', ['search' => 'Teclado']))
        ->assertOk()
        ->assertInertia(fn (Assert $page) => $page
            ->component('Products/Index')
            ->has('items.data', 1)
            ->where('items.data.0.sku', 'TEC-001')
        );
});

/*
|--------------------------------------------------------------------------
| 4. Testes de Validação (Form Requests)
|--------------------------------------------------------------------------
*/

test('cadastro exige nome, sku e preco valido', function (array $payloadInvalido, string $campoComErro): void {
    $this->actingAs($this->user)
        ->post(route('products.store'), $payloadInvalido)
        ->assertSessionHasErrors([$campoComErro]);
})->with([
    'nome ausente' => [['sku' => 'ABC-123', 'price' => 99.90], 'name'],
    'sku ausente' => [['name' => 'Teclado', 'price' => 99.90], 'sku'],
    'preco negativo' => [['name' => 'Teclado', 'sku' => 'ABC-123', 'price' => -10], 'price'],
    'preco em formato textual invalido' => [['name' => 'Teclado', 'sku' => 'ABC-123', 'price' => 'cem'], 'price'],
    'status invalido' => [['name' => 'Teclado', 'sku' => 'ABC-123', 'price' => 10, 'status' => 'status_inexistente'], 'status'],
]);

test('sku deve ser unico dentro do mesmo tenant', function (): void {
    Product::factory()->create([
        'tenant_id' => $this->tenant->id,
        'sku' => 'SKU-DUPLICADO',
    ]);

    $this->actingAs($this->user)
        ->post(route('products.store'), [
            'name' => 'Outro Produto',
            'sku' => 'SKU-DUPLICADO',
            'price' => 150.00,
            'status' => 'active',
        ])
        ->assertSessionHasErrors(['sku']);
});

/*
|--------------------------------------------------------------------------
| 5. Testes de Mutação (Persistência, Soft Deletes e Flash Messages)
|--------------------------------------------------------------------------
*/

test('usuario autenticado pode cadastrar um novo produto com dados validos', function (): void {
    $payload = [
        'name' => 'Monitor Gamer 144Hz',
        'sku' => 'MON-144-01',
        'price' => 1299.90,
        'status' => 'active',
        'description' => 'Monitor com alta taxa de atualização.',
    ];

    $response = $this->actingAs($this->user)
        ->post(route('products.store'), $payload);

    $response->assertRedirect(route('products.index'))
        ->assertSessionHas('success');

    $this->assertDatabaseHas('products', [
        'tenant_id' => $this->tenant->id,
        'name' => 'Monitor Gamer 144Hz',
        'sku' => 'MON-144-01',
        'status' => 'active',
    ]);
});

test('usuario autenticado pode atualizar um produto existente', function (): void {
    $produto = Product::factory()->create([
        'tenant_id' => $this->tenant->id,
        'name' => 'Nome Antigo',
        'price' => 100.00,
    ]);

    $response = $this->actingAs($this->user)
        ->put(route('products.update', $produto), [
            'name' => 'Nome Atualizado',
            'sku' => $produto->sku,
            'price' => 189.90,
            'status' => 'active',
        ]);

    $response->assertRedirect(route('products.index'))
        ->assertSessionHas('success');

    $this->assertDatabaseHas('products', [
        'id' => $produto->id,
        'name' => 'Nome Atualizado',
        'price' => 189.90,
    ]);
});

test('usuario pode remover um produto aplicando soft delete', function (): void {
    $produto = Product::factory()->create([
        'tenant_id' => $this->tenant->id,
        'name' => 'Produto a Deletar',
    ]);

    $response = $this->actingAs($this->user)
        ->delete(route('products.destroy', $produto));

    $response->assertRedirect(route('products.index'))
        ->assertSessionHas('success');

    $this->assertSoftDeleted('products', [
        'id' => $produto->id,
    ]);
});
```

---

## Etapa 4: Auditoria e Execução dos Testes

Ao finalizar a escrita dos testes:

1. **Executar a suíte específica no terminal:**
   ```bash
   ./vendor/bin/pest tests/Feature/Products/ProductTest.php
   ```

2. **Verificar relatório de cobertura de código:**
   ```bash
   ./vendor/bin/pest tests/Feature/Products/ProductTest.php --coverage --min=90
   ```

3. **Verificação de Estilo e Tipos:**
   Execute a validação estática nos arquivos de teste:
   ```bash
   ./vendor/bin/pint tests/Feature/Products/ProductTest.php
   ./vendor/bin/phpstan analyse tests/Feature/Products/ProductTest.php
   ```

---

## Etapa 5: Checklist de Qualidade do Teste

Antes de concluir a suíte, certifique-se de que:
- [ ] O teste usa a trait `RefreshDatabase` para garantir isolamento de estado.
- [ ] Não há asserções genéricas de status HTTP (ex.: esperar `assertOk()` quando a rota deve redirecionar via `assertRedirect()`).
- [ ] O `assertInertia` valida a árvore exata de propriedades que o frontend consome (`items.data`, `filters`).
- [ ] Testes de validação cobrem os múltiplos casos usando datasets `->with([...])` para manter o código enxuto.
- [ ] Nenhum ID está mockado de forma fixa (ex.: sempre utilize `$produto->id` ou instâncias geradas por factories).