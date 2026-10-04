---
name: gerar-teste-vitest
author: Seu Nome <seu.email@exemplo.com>
description: Cria e audita testes unitários e de integração no frontend com Vitest e Vue Test Utils para composables, utilitários, stores e componentes shadcn-vue.
---

# Skill: Geração de Testes de Frontend (Vitest + Vue Test Utils)

Esta skill estabelece o guia oficial para implementar testes de unidade e componentes com **Vitest** e **@vue/test-utils** no ecossistema Vue 3 (Composition API) + shadcn-vue + Inertia.js.

---

## Etapa 1: Pré-requisitos & Dependências do Frontend

Certifique-se de que o ambiente de testes do frontend contém os pacotes adequados em `package.json`:

```bash
npm install -D vitest @vue/test-utils jsdom happy-dom
```

Verifique se a configuração do `vite.config.ts` possui o bloco `test`:

```typescript
/// <reference types="vitest" />
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import path from 'path';

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './resources/js'),
    },
  },
  test: {
    globals: true,
    environment: 'happy-dom',
  },
});
```

---

## Etapa 2: A Matriz de Testes de Frontend

Divida os testes de frontend em 3 categorias essenciais:

1. **Formatadores e Funções Utilitárias (`resources/js/lib/`):** Teste de entrada e saída pura com asserções numéricas e monetárias.
2. **Composables Reativos (`resources/js/composables/`):** Teste de estado reativo, mutações e debounce com timers fictícios (`vi.useFakeTimers()`).
3. **Componentes shadcn-vue & Partials (`resources/js/components/`):** Renderização, emissão de eventos e reatividade a props.

---

## Etapa 3: Exemplo 1 — Teste de Função Utilitária (`lib/utils.test.ts`)

```typescript
import { describe, it, expect } from 'vitest';
import { cn } from '@/lib/utils';

describe('Utilitário cn()', () => {
  it('combina classes css corretamente respeitando precedência do tailwind', () => {
    const result = cn('px-4 py-2', 'px-6', { 'bg-primary': true, 'opacity-50': false });
    
    // tailwind-merge deve priorizar px-6 sobre px-4
    expect(result).toContain('px-6');
    expect(result).not.toContain('px-4');
    expect(result).toContain('bg-primary');
    expect(result).not.toContain('opacity-50');
  });
});
```

---

## Etapa 4: Exemplo 2 — Teste de Composable Reativo (`useDebounce.test.ts`)

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ref } from 'vue';
import { useDebounce } from '@/composables/useDebounce';

describe('Composable useDebounce', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('atualiza o valor somente apos o tempo de debounce configurado', () => {
    const termo = ref('Laravel');
    const termoDebounced = useDebounce(termo, 300);

    expect(termoDebounced.value).toBe('Laravel');

    termo.value = 'Laravel 12';
    expect(termoDebounced.value).toBe('Laravel'); // Ainda não atualizou

    vi.advanceTimersByTime(299);
    expect(termoDebounced.value).toBe('Laravel');

    vi.advanceTimersByTime(1);
    expect(termoDebounced.value).toBe('Laravel 12'); // Atualizado após 300ms
  });
});
```

---

## Etapa 5: Exemplo 3 — Teste de Componente Dialog / Modal

Crie o arquivo em `resources/js/pages/Products/Partials/ProductFormDialog.test.ts`:

```typescript
import { describe, it, expect, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import ProductFormDialog from './ProductFormDialog.vue';

// Mock do Inertia useForm
vi.mock('@inertiajs/vue3', () => ({
  useForm: vi.fn((initialData) => ({
    ...initialData,
    processing: false,
    errors: {},
    post: vi.fn(),
    put: vi.fn(),
    reset: vi.fn(),
    clearErrors: vi.fn(),
  })),
}));

// Mock do Laravel Wayfinder
vi.mock('@/routes/products', () => ({
  store: () => ({ url: '/products' }),
  update: ({ product }: { product: number }) => ({ url: `/products/${product}` }),
}));

describe('Componente ProductFormDialog', () => {
  it('renderiza o titulo de criacao quando o item for nulo', () => {
    const wrapper = mount(ProductFormDialog, {
      props: {
        open: true,
        item: null,
      },
    });

    expect(wrapper.text()).toContain('Cadastrar Novo Produto');
  });

  it('renderiza o titulo de edicao quando o item possuir dados', () => {
    const wrapper = mount(ProductFormDialog, {
      props: {
        open: true,
        item: {
          id: 42,
          name: 'Teclado Mecânico',
          sku: 'TEC-01',
          price: 299.90,
          status: 'active',
          created_at: '2026-01-01',
        },
      },
    });

    expect(wrapper.text()).toContain('Editar Produto');
  });

  it('emite o evento update:open ao acionar o botao cancelar', async () => {
    const wrapper = mount(ProductFormDialog, {
      props: {
        open: true,
        item: null,
      },
    });

    const botaoCancelar = wrapper.findAll('button').find(b => b.text().includes('Cancelar'));
    expect(botaoCancelar).toBeDefined();

    await botaoCancelar?.trigger('click');

    expect(wrapper.emitted('update:open')).toBeTruthy();
    expect(wrapper.emitted('update:open')![0]).toEqual([false]);
  });
});
```

---

## Etapa 6: Validação e Execução

Execute os testes no terminal com relatório detalhado:

```bash
npx vitest run
```

E para cobertura de código:

```bash
npx vitest run --coverage
```

---

## Etapa 7: Checklist de Qualidade dos Testes de Frontend

- [ ] Todos os testes utilizam sintaxe limpa de Composition API e TypeScript.
- [ ] Chamadas HTTP e helpers de roteamento (`@/routes/*`) são isolados via mocks.
- [ ] Timers assíncronos (debounces e atrasos) são controlados via `vi.useFakeTimers()`.
- [ ] Componentes acessíveis verificam a emissão correta de eventos (`v-model:open`, `success`).
- [ ] O comando `npx vitest run` executa em menos de 5 segundos sem vazamento de memória.