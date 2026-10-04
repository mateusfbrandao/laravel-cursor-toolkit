## name: refatorar-controller-para-action

description: Refatora controllers legados ou com excesso de responsabilidade (fat controllers), desacoplando validações inline em Form Requests, transferências de dados em DTOs imutáveis e regras de negócio em Actions puras e testáveis.

# Skill: Refatoração de Controllers para Actions & DTOs

Esta skill orienta o processo sistemático e seguro para desmembrar controllers sobrecarregados (*fat controllers*), código legado ou métodos de endpoint com lógica procedural acoplada no ecossistema **Laravel + Inertia.js**.

Siga rigorosamente a ordem das etapas para garantir refatoração sem quebra de comportamento (*zero-regression*), mantendo a compatibilidade de rotas e preservando a integridade das respostas Inertia/JSON.

---

## Etapa 1: Diagnóstico e Mapeamento de Responsabilidades

Antes de alterar qualquer linha de código no controller alvo, identifique e marque os 4 componentes dispersos no método:

1. **Validação Inline:** Chamadas a `$request->validate([...])` ou `Validator::make(...)`.
2. **Autorização Implícita:** Checagens manuais de `auth()->user()->role === 'admin'` ou `abort_if(...)`.
3. **Mutações de Negócio & Efeitos Colaterais:** Criação de models, uploads de arquivos, disparos de eventos/jobs, envio de e-mails transacionais e chamadas a APIs externas.
4. **Preparação de Resposta:** Redirecionamentos com flash messages ou renderizações `Inertia::render()`.

---

## Etapa 2: Extração da Validação para Form Request

Nunca mantenha regras de validação dentro do controller ou da Action.

Crie a classe de request em `app/Http/Requests/{Entity}/`:

```bash
php artisan make:request {Entity}/{ActionName}{Entity}Request
```

Exemplo: `app/Http/Requests/Order/CheckoutOrderRequest.php`:

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests\Order;

use App\Models\Order;
use Illuminate\Foundation\Http\FormRequest;

final class CheckoutOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        /** @var Order $order */
        $order = $this->route('order');

        return $this->user()?->can('checkout', $order) ?? false;
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'payment_method' => ['required', 'string', 'in:credit_card,pix,boleto'],
            'installments' => ['required', 'integer', 'min:1', 'max:12'],
            'customer_notes' => ['nullable', 'string', 'max:500'],
        ];
    }
}
```

---

## Etapa 3: Criação do DTO Imutável de Entrada

Isole os dados validados em um DTO tipado para evitar que a Action dependa diretamente do ciclo HTTP (`Request`).

Crie a classe em `app/DTOs/{Entity}/{ActionName}{Entity}Data.php`:

```php
<?php

declare(strict_types=1);

namespace App\DTOs\Order;

use App\Http\Requests\Order\CheckoutOrderRequest;

final readonly class CheckoutOrderData
{
    public function __construct(
        public string $paymentMethod,
        public int $installments,
        public ?string $customerNotes,
    ) {}

    public static function fromRequest(CheckoutOrderRequest $request): self
    {
        /** @var array{payment_method: string, installments: int, customer_notes: ?string} $data */
        $data = $request->validated();

        return new self(
            paymentMethod: $data['payment_method'],
            installments: (int) $data['installments'],
            customerNotes: $data['customer_notes'] ?? null,
        );
    }
}
```

---

## Etapa 4: Extração da Regra de Negócio para Action

Crie a Action com método invocável `__invoke` em `app/Actions/{Entity}/`:

```php
<?php

declare(strict_types=1);

namespace App\Actions\Order;

use App\DTOs\Order\CheckoutOrderData;
use App\Enums\OrderStatus;
use App\Events\OrderPlacedEvent;
use App\Models\Order;
use Illuminate\Support\Facades\DB;

final class CheckoutOrderAction
{
    public function __invoke(Order $order, CheckoutOrderData $data): Order
    {
        return DB::transaction(function () use ($order, $data): Order {
            $order->update([
                'status' => OrderStatus::Processing,
                'payment_method' => $data->paymentMethod,
                'installments' => $data->installments,
                'customer_notes' => $data->customerNotes,
                'checked_out_at' => now(),
            ]);

            // Disparo de efeitos colaterais após mutação garantida
            event(new OrderPlacedEvent($order));

            return $order->fresh();
        });
    }
}
```

---

## Etapa 5: Emagrecimento do Controller (Slim Controller)

Substitua o método inflado anterior por uma chamada concisa (5 a 8 linhas) com injeção de dependência:

### Antes (Fat Controller Antigo):
```php
public function checkout(Request $request, $id)
{
    $order = Order::findOrFail($id);
    if ($order->user_id !== auth()->id()) {
        abort(403);
    }

    $validated = $request->validate([
        'payment_method' => 'required',
        'installments' => 'required|numeric',
    ]);

    $order->status = 'processing';
    $order->payment_method = $validated['payment_method'];
    $order->installments = $validated['installments'];
    $order->save();

    Mail::to($request->user())->send(new OrderReceipt($order));

    return redirect()->route('orders.show', $order->id)->with('success', 'Pedido efetuado!');
}
```

### Depois (Slim Controller Refatorado):
```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Actions\Order\CheckoutOrderAction;
use App\DTOs\Order\CheckoutOrderData;
use App\Http\Requests\Order\CheckoutOrderRequest;
use App\Models\Order;
use Illuminate\Http\RedirectResponse;

final class OrderController extends Controller
{
    public function checkout(
        CheckoutOrderRequest $request,
        Order $order,
        CheckoutOrderAction $action
    ): RedirectResponse {
        $action($order, CheckoutOrderData::fromRequest($request));

        return redirect()
            ->route('orders.show', $order)
            ->with('success', 'Pedido finalizado com sucesso.');
    }
}
```

---

## Etapa 6: Auditoria Pós-Refatoração

Após a separação de camadas, valide a integridade do código:

1. **Formatação de Código com Pint:**
   ```bash
   ./vendor/bin/pint app/Http/Controllers/OrderController.php app/Http/Requests/Order/ app/DTOs/Order/ app/Actions/Order/
   ```

2. **Análise Estática com Larastan:**
   ```bash
   ./vendor/bin/phpstan analyse app/Http/Controllers/OrderController.php app/Http/Requests/Order/ app/DTOs/Order/ app/Actions/Order/ --no-progress
   ```

3. **Execução da Suíte de Testes:**
   ```bash
   ./vendor/bin/pest tests/Feature/OrderTest.php
   ```

---

## Etapa 7: Checklist de Qualidade da Refatoração

- [ ] O controller possui no máximo 10 linhas por método de ação.
- [ ] Nenhuma query direta do Eloquent (`::create`, `::update`, `::where`) reside no controller.
- [ ] A Action não possui dependências da classe `Illuminate\Http\Request`.
- [ ] A autorização de usuário foi delegada à Policy correspondente.
- [ ] Mutações críticas em tabelas foram envelopadas em `DB::transaction`.