#!/usr/bin/env bash

# ==============================================================================
# Laravel Vibe Toolkit - Script de Instalação e Governança
# ==============================================================================
# Este script sincroniza os agentes, skills, regras de governança, templates
# de CI/CD, configuração estrita do Larastan (Nível 8) e design system Impeccable.
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-.}"

echo "🚀 Iniciando configuração do Laravel Vibe Toolkit em: ${TARGET_DIR}"

# 1. Criação das estruturas de diretórios necessárias
echo "📁 Criando diretórios de governança..."
mkdir -p "${TARGET_DIR}/.cursor/agents"
mkdir -p "${TARGET_DIR}/.cursor/skills"
mkdir -p "${TARGET_DIR}/.cursor/rules"
mkdir -p "${TARGET_DIR}/.github/workflows"

# 2. Sincronização de Agentes e Skills
echo "🤖 Sincronizando Agentes Especializados..."
if [ -d "${ROOT_DIR}/templates/.cursor/agents" ]; then
    cp -u "${ROOT_DIR}/templates/.cursor/agents/"*.md "${TARGET_DIR}/.cursor/agents/" 2>/dev/null || true
fi

echo "⚡ Sincronizando Skills Operacionais..."
if [ -d "${ROOT_DIR}/templates/.cursor/skills" ]; then
    cp -ru "${ROOT_DIR}/templates/.cursor/skills/"* "${TARGET_DIR}/.cursor/skills/" 2>/dev/null || true
fi

# 3. Sincronização de Regras Globais (.cursor/rules/)
echo "📏 Sincronizando Regras MDC do Cursor..."
if [ -d "${ROOT_DIR}/templates/.cursor/rules" ]; then
    cp -u "${ROOT_DIR}/templates/.cursor/rules/"*.mdc "${TARGET_DIR}/.cursor/rules/" 2>/dev/null || true
fi

# 4. Configuração de CI/CD e Análise Estática (Larastan Nível 8)
echo "🛡️ Configurando phpstan.neon e GitHub Actions..."
if [ -f "${ROOT_DIR}/templates/phpstan.neon" ] && [ ! -f "${TARGET_DIR}/phpstan.neon" ]; then
    cp "${ROOT_DIR}/templates/phpstan.neon" "${TARGET_DIR}/phpstan.neon"
    echo "✓ phpstan.neon criado (Nível 8)."
fi

if [ -f "${ROOT_DIR}/templates/.github/workflows/ci.yml" ] && [ ! -f "${TARGET_DIR}/.github/workflows/ci.yml" ]; then
    cp "${ROOT_DIR}/templates/.github/workflows/ci.yml" "${TARGET_DIR}/.github/workflows/ci.yml"
    echo "✓ GitHub Actions CI/CD instalado em .github/workflows/ci.yml."
fi

# 5. Instalação e Calibração do Impeccable (Design System & Polish)
echo "🎨 [Frontend] Integrando diretrizes do Impeccable..."
if command -v npx &> /dev/null; then
    echo "📦 Executando 'npx -y impeccable install'..."
    (cd "${TARGET_DIR}" && npx -y impeccable install) || {
        echo "⚠️ Atenção: 'npx impeccable install' retornou código não-zero. Verifique a conexão de rede."
    }
    echo "✓ Impeccable integrado ao ambiente."
else
    echo "⚠️ 'npx' não encontrado no PATH. Instale o Node.js/NPM para obter o Impeccable."
fi

# 6. Verificação de Dependências PHP de Qualidade
echo "🔍 Verificando ferramentas de qualidade no composer.json..."
if [ -f "${TARGET_DIR}/composer.json" ]; then
    PACKAGES_TO_SUGGEST=()

    grep -q '"larastan/larastan"' "${TARGET_DIR}/composer.json" || PACKAGES_TO_SUGGEST+=("larastan/larastan:^2.0")
    grep -q '"laravel/pint"' "${TARGET_DIR}/composer.json" || PACKAGES_TO_SUGGEST+=("laravel/pint:^1.0")
    grep -q '"pestphp/pest"' "${TARGET_DIR}/composer.json" || PACKAGES_TO_SUGGEST+=("pestphp/pest:^3.0")
    grep -q '"laravel/boost"' "${TARGET_DIR}/composer.json" || PACKAGES_TO_SUGGEST+=("laravel/boost:^1.0")

    if [ ${#PACKAGES_TO_SUGGEST[@]} -ne 0 ]; then
        echo "💡 Recomendado instalar pacotes pendentes de QA via Composer:"
        echo "   composer require --dev ${PACKAGES_TO_SUGGEST[*]}"
    else
        echo "✓ Ferramentas de QA (Larastan, Pint, Pest) já declaradas no composer.json."
    fi      
fi

# 7. Execução de comandos do Laravel Boost (se presente)
if [ -f "${TARGET_DIR}/artisan" ]; then
    if php "${TARGET_DIR}/artisan" list 2>/dev/null | grep -q "boost:install"; then
        echo "⚡ A executar configuração do Laravel Boost..."
        php "${TARGET_DIR}/artisan" boost:install --no-interaction || true
        echo "✓ Laravel Boost configurado."
    fi
fi

# 8. Verificação de Baseline para Projetos Existentes/Legados
if [ -f "${TARGET_DIR}/phpstan.neon" ]; then
    if [ ! -f "${TARGET_DIR}/phpstan-baseline.neon" ]; then
        echo ""
        echo "📌 Dica para Código Legado:"
        echo "   Se estiver adotando o toolkit em um projeto existente, gere a baseline inicial:"
        echo "   ./vendor/bin/phpstan analyse --generate-baseline"
    fi
fi

echo ""
echo "✨ Laravel Vibe Toolkit aplicado com sucesso!"
