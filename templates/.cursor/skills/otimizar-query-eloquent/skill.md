## name: otimizar-query-eloquent

description: Diagnostica, refatora e otimiza consultas Eloquent de baixa performance no ecossistema Laravel, eliminando gargalos de N+1, reduzindo consumo de memória (RAM), transferindo agregações para o banco de dados e criando testes de asserção de contagem de queries com Pest PHP.

# Skill: Otimização de Consultas Eloquent & Prevenção de N+1

Esta skill estabelece o guia sistemático de engenharia de software para diagnosticar, auditar e otimizar queries lentas, gargalos de alocação de memória e consultas $N+1$ em aplicações **Laravel**.

Siga estritamente as etapas para garantir que o processamento seja empurrado para o motor do banco de dados (MySQL/PostgreSQL), mantendo o código limpo, fortemente tipado e blindado contra regressões.

---

## Etapa 1: Diagnóstico e Detecção de Gargalos

Antes de alterar qualquer código, identifique a origem do problema:

1. **Ativação do Strict Mode em Desenvolvimento:**
   Certifique-se de que o Laravel bloqueia *lazy loading* não intencional em `AppServiceProvider::boot()`:
   ```php
   use Illuminate\Database\Eloquent\Model;

   public function boot(): void
   {
       Model::shouldBeStrict(! $this->app->isProduction());
   }
   ```
   *Efeito:* Qualquer carregamento implícito de relação dispara uma `LazyLoadingViolationException` imediata em desenvolvimento e testes.

2. **Instrumentação da Contagem de Queries:**
   Inspecione as queries disparadas na requisição ou job via Laravel Boost (MCP), Laravel Telescope ou interceptando com `DB::listen()`:
   ```php
   use Illuminate\Support\Facades\DB;
   use Illuminate\Support\Facades\Log;

   DB::listen(function ($query): void {
       if ($query->time > 100) { // Queries lentas acima de 100ms
           Log::warning("Query Lenta ({$query->time}ms): {$query->sql}", [
               'bindings' => $query->bindings,
           ]);
       }
   });
   ```

---

## Etapa 2: Resolução de N+1 com Eager Loading Explícito

### Cenário Problemático (Anti-Pattern):
```php
// Ruim: 1 query para pedidos + N queries para clientes + N queries para itens
$orders = Order::all();

foreach ($orders as $order) {
    echo $order->customer->name;
    echo $order->items->count();
}
```

### Refatoração Otimizada:
Utilize `with()` com projeção estrita de colunas (incluindo sempre chaves primárias e estrangeiras) e `withCount()` para evitar carregar coleções inteiras apenas para contagem:

```php
<?php

declare(strict_types=1);

namespace App\Actions\Order;

use App\Models\Order;
use Illuminate\Database\Eloquent\Collection;

final class ListRecentOrdersAction
{
    /**
     * @return Collection<int, Order>
     */
    public function __invoke(): Collection
    {
        return Order::query()
            ->select(['id', 'customer_id', 'status', 'total_amount', 'created_at'])
            ->with([
                'customer' => fn ($query) => $query->select(['id', 'name', 'email']),
            ])
            ->withCount('items') // Cria a propriedade virtual 'items_count' sem carregar os models
            ->latest('id')
            ->limit(50)
            ->get();
    }
}
```

---

## Etapa 3: Subqueries Dinâmicas vs. Joins Inflados

Quando precisar de dados agregados ou do registro "mais recente" de uma relação filha, utilize `addSelect()` com subqueries Eloquent em vez de carregar relações inteiras ou inflar a memória com múltiplos joins.

### Exemplo: Última Compra do Cliente
```php
<?php

declare(strict_types=1);

namespace App\Actions\Customer;

use App\Models\Customer;
use App\Models\Order;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

final class ListCustomersWithLastOrderAction
{
    /**
     * @return LengthAwarePaginator<Customer>
     */
    public function __invoke(): LengthAwarePaginator
    {
        return Customer::query()
            ->select(['id', 'name', 'email', 'created_at'])
            ->addSelect([
                'last_order_amount' => Order::query()
                    ->select('total_amount')
                    ->whereColumn('customer_id', 'customers.id')
                    ->latest('id')
                    ->limit(1),
                'last_order_at' => Order::query()
                    ->select('created_at')
                    ->whereColumn('customer_id', 'customers.id')
                    ->latest('id')
                    ->limit(1),
            ])
            ->paginate(15);
    }
}
```

---

## Etapa 4: Processamento Massivo com Controle Estrito de Memória

Para comandos, exportações ou processamento em fila, **NUNCA** execute `Model::all()` ou `Model::get()` em tabelas volumosas.

### 1. `chunkById()` (Mutações e Processamento em Lote)
Usa cursores indexados pela chave primária, prevenindo loops infinitos caso a query altere colunas filtradas:

```php
Order::query()
    ->where('status', 'pending')
    ->where('created_at', '<', now()->subDays(7))
    ->chunkById(250, function ($orders): void {
        foreach ($orders as $order) {
            $order->update(['status' => 'cancelled']);
        }
    });
```

### 2. `lazyById()` (Lazy Collections com Baixo Overhead)
Utiliza geradores PHP (`yield`) para iterar milhares de registros mantendo apenas 1 registro em memória por vez:

```php
use App\Models\User;

User::query()
    ->whereNull('email_verified_at')
    ->lazyById(500)
    ->each(function (User $user): void {
        dispatch(new SendReminderJob($user->id));
    });
```

---

## Etapa 5: Migrations de Apoio & Índices Compostos

Nenhuma otimização de Eloquent compensa a falta de índices adequados na engine do banco.

Ao identificar filtros frequentes combinados com ordenação, crie migrations adicionando índices compostos no padrão `(filtro, ordenação)`:

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
        Schema::table('orders', function (Blueprint $table): void {
            // Otimiza queries como: WHERE tenant_id = ? AND status = ? ORDER BY id DESC
            $table->index(['tenant_id', 'status', 'id'], 'idx_orders_tenant_status_id');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropIndex('idx_orders_tenant_status_id');
        });
    }
};
```

---

## Etapa 6: Teste de Desempenho e Asserção de Queries no Pest PHP

Crie testes automatizados que garantam que uma refatoração não sofra regressão para $N+1$ no futuro:

```php
<?php

declare(strict_types=1);

use App\Actions\Order\ListRecentOrdersAction;
use App\Models\Customer;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

test('listagem de pedidos nao sofre de regressao de consultas N+1', function (): void {
    // 1. Arrange: Cria múltiplos clientes e pedidos com itens
    Customer::factory()
        ->count(5)
        ->has(
            Order::factory()
                ->count(2)
                ->has(OrderItem::factory()->count(3), 'items')
        )
        ->create();

    // 2. Instrumentação de contagem
    $queryCount = 0;
    DB::listen(function () use (&$queryCount): void {
        $queryCount++;
    });

    // 3. Act
    $action = app(ListRecentOrdersAction::class);
    $orders = $action();

    // Simula renderização dos dados na view/resource
    foreach ($orders as $order) {
        $name = $order->customer->name;
        $itemsCount = $order->items_count;
    }

    // 4. Assert:
    // Query 1: Seleção de orders com items_count
    // Query 2: Eager loading dos customers
    // Total máximo esperado: exatamente 2 queries, independentemente da quantidade de registros
    expect($queryCount)->toBe(2);
});
```

---

## Etapa 7: Checklist de Auditoria de Performance

Antes de considerar a query otimizada:
- [ ] `Model::shouldBeStrict()` está configurado no ambiente de desenvolvimento/testes.
- [ ] O teste de feature com asserção de limite de queries (`DB::listen`) foi executado e aprovado.
- [ ] Todas as chamadas `with()` projetam apenas as colunas estritamente necessárias (incluindo chaves estrangeiras/primárias).
- [ ] Contagens e agregações utilizam `withCount()`, `sum()`, `avg()` direto no SQL em vez de métodos de Collection em memória.
- [ ] Mutações e varreduras em lote utilizam `chunkById()` ou `lazyById()`.
- [ ] O código foi formatado com `./vendor/bin/pint` e validado com `./vendor/bin/phpstan analyse`.
