## name: criar-fluxo-email

description: Cria e gerencia fluxos completos de envio de e-mails transacionais e notificações em segundo plano (Queued Mailables), encapsulando dados em DTOs/Models, utilizando layouts responsivos e cobrindo os disparos com testes automatizados em Pest PHP.

# Skill: Criação de Fluxo de E-mail Assíncrono (Queued Mailable)

Esta skill estabelece o padrão arquitetural e de qualidade para a criação de e-mails transacionais assíncronos no ecossistema **Laravel**.

Siga rigorosamente a ordem das etapas para garantir que envios de mensagens não bloqueiem o ciclo de requisição HTTP, utilizem tipagem estrita e contenham cobertura de testes automatizados com `Mail::fake()`.

---

## Etapa 1: Diagnóstico e Definição do Contrato de Dados

Antes de gerar a classe de e-mail, identifique:
1. **Dados Necessários:** Extraia apenas as informações estritamente necessárias para a renderização, preferindo IDs, DTOs imutáveis ou Models Eloquent persistidos.
2. **Momento do Disparo:** E-mails transacionais NUNCA devem ser disparados diretamente dentro do controller. O disparo deve ocorrer via Action ou dentro de um Listener acionado por Domain Events.
3. **Execução Assíncrona:** Todo e-mail transacional deve implementar a interface `ShouldQueue` para processamento via fila (Redis, database, etc.).

---

## Etapa 2: Criação da Classe Mailable

Gere o mailable com suporte a fila via Artisan:

```bash
php artisan make:mail {Domain}/{MailableName} --queued
```

Exemplo: `app/Mail/Order/OrderReceiptMail.php`:

```php
<?php

declare(strict_types=1);

namespace App\Mail\Order;

use App\Models\Order;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Address;
use Illuminate\Mail\Mailables\Attachment;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

final class OrderReceiptMail extends Mailable implements ShouldQueue
{
    use Queueable;
    use SerializesModels;

    public function __construct(
        public readonly Order $order,
        public readonly User $recipient,
    ) {
        $this->onQueue('emails');
    }

    public function envelope(): Envelope
    {
        return new Envelope(
            to: [new Address($this->recipient->email, $this->recipient->name)],
            subject: "Comprovante do Pedido #{$this->order->id}",
            tags: ['order', 'receipt'],
            metadata: [
                'order_id' => (string) $this->order->id,
            ],
        );
    }

    public function content(): Content
    {
        return new Content(
            markdown: 'emails.orders.receipt',
            with: [
                'orderNumber' => $this->order->id,
                'customerName' => $this->recipient->name,
                'totalAmount' => $this->order->total_amount,
                'items' => $this->order->items,
                'viewUrl' => route('orders.show', $this->order),
            ],
        );
    }

    /**
     * @return array<int, Attachment>
     */
    public function attachments(): array
    {
        return [];
    }
}
```

---

## Etapa 3: Template Responsivo de E-mail

Crie o arquivo de template Markdown em `resources/views/emails/{domain}/{template}.blade.php`:

```blade
<x-mail::message>
# Olá, {{ $customerName }}!

Agradecemos pela sua compra. Seu pedido **#{{ $orderNumber }}** foi recebido e já está sendo processado por nossa equipe.

<x-mail::panel>
**Resumo Financeiro:**  
Total: **R$ {{ number_format($totalAmount / 100, 2, ',', '.') }}**
</x-mail::panel>

<x-mail::table>
| Item | Quantidade | Preço |
| :--- | :---: | ---: |
@foreach ($items as $item)
| {{ $item->name }} | {{ $item->quantity }} | R$ {{ number_format($item->price / 100, 2, ',', '.') }} |
@endforeach
</x-mail::table>

Caso queira acompanhar o status em tempo real, clique no botão abaixo:

<x-mail::button :url="$viewUrl">
Visualizar Pedido
</x-mail::button>

Se tiver qualquer dúvida, basta responder diretamente a esta mensagem.

Atenciosamente,  
**Equipe {{ config('app.name') }}**
</x-mail::message>
```

---

## Etapa 4: Integração na Action de Negócio

Dispare o envio assíncrono na Action utilizando `Mail::to()->queue()` ou através da injeção do mailable com `ShouldQueue`:

```php
<?php

declare(strict_types=1);

namespace App\Actions\Order;

use App\Mail\Order\OrderReceiptMail;
use App\Models\Order;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;

final class FinalizeOrderAction
{
    public function __invoke(Order $order): Order
    {
        return DB::transaction(function () use ($order): Order {
            $order->update([
                'status' => 'completed',
                'completed_at' => now(),
            ]);

            // Disparo assíncrono garantido após sucesso da transação
            Mail::to($order->user)->queue(new OrderReceiptMail($order, $order->user));

            return $order->fresh();
        });
    }
}
```

---

## Etapa 5: Testes Automatizados com Pest PHP

Crie o teste de feature em `tests/Feature/Mail/{Domain}/{MailableName}Test.php`:

```php
<?php

declare(strict_types=1);

use App\Actions\Order\FinalizeOrderAction;
use App\Mail\Order\OrderReceiptMail;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;

uses(RefreshDatabase::class);

test('disparo do mailable de recibo de pedido eh enfileirado com os destinatarios corretos', function (): void {
    Mail::fake();

    $user = User::factory()->create([
        'name' => 'Cliente Teste',
        'email' => 'cliente@exemplo.com',
    ]);

    $order = Order::factory()->create([
        'user_id' => $user->id,
        'total_amount' => 15000,
    ]);

    OrderItem::factory()->count(2)->create([
        'order_id' => $order->id,
    ]);

    $action = app(FinalizeOrderAction::class);
    $action($order);

    Mail::assertQueued(OrderReceiptMail::class, function (OrderReceiptMail $mail) use ($user, $order): bool {
        return $mail->hasTo($user->email)
            && $mail->order->id === $order->id
            && $mail->recipient->id === $user->id;
    });
});

test('mailable renderiza o conteudo esperado e assunto customizado', function (): void {
    $user = User::factory()->make([
        'name' => 'Maria Silva',
        'email' => 'maria@exemplo.com',
    ]);

    $order = Order::factory()->make([
        'id' => 987,
        'total_amount' => 25000,
    ]);

    $mailable = new OrderReceiptMail($order, $user);

    $mailable->assertHasSubject('Comprovante do Pedido #987');
    $mailable->assertSeeInHtml('Maria Silva');
    $mailable->assertSeeInHtml('987');
});
```

---

## Etapa 6: Auditoria e Validação de Tipos

Finalizada a implementação, execute a validação:

1. **Formatação com Pint:**
   ```bash
   ./vendor/bin/pint app/Mail/ app/Actions/ tests/Feature/Mail/
   ```

2. **Análise Estática com Larastan:**
   ```bash
   ./vendor/bin/phpstan analyse app/Mail/ app/Actions/ tests/Feature/Mail/ --no-progress
   ```

3. **Execução da Suíte de Testes do Mailable:**
   ```bash
   ./vendor/bin/pest tests/Feature/Mail/
   ```

---

## Etapa 7: Checklist de Qualidade do Mailable

- [ ] A classe implementa `Illuminate\Contracts\Queue\ShouldQueue`.
- [ ] O construtor define `$this->onQueue('emails')` ou nome de fila explícito.
- [ ] Nenhum envio direto ocorre em Controllers; a responsabilidade reside em Actions ou Listeners.
- [ ] Os métodos `envelope()`, `content()` e `attachments()` possuem tipagens estritas.
- [ ] O teste cobre tanto a asserção de fila (`Mail::assertQueued`) quanto a renderização do corpo/assunto (`assertSeeInHtml`).