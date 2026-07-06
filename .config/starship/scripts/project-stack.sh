#!/usr/bin/env bash

# ==============================================================================
# Starship Project Stack
# ------------------------------------------------------------------------------
# Detects frontend/backend stack, tools, runtimes, and package manager then
# renders Starship markup.
#
# Requirements:
# - Bash 4+
# - jq
# - Linux / macOS
# ==============================================================================

set -o nounset
set -o pipefail

# ==============================================================================
# Metadata Registry
#
# Format:
#   key="icon|color|label"
#
# Single source of truth untuk seluruh metadata.
# ==============================================================================

declare -Ar META=(

  # --------------------------------------------------------------------------
  # Frontend
  # --------------------------------------------------------------------------

  [next]="|lavender|Next.js"
  [astro]="|mauve|Astro"
  [nuxt]="󱄆|green|Nuxt"
  [vite]="|yellow|Vite"
  [react]="󰜈|sapphire|React"
  [vue]="󰡄|green|Vue"

  # --------------------------------------------------------------------------
  # Backend
  # --------------------------------------------------------------------------

  [laravel]="󰫐|red|Laravel"
  [inertia]="󰘦|lavender|Inertia"
  [livewire]="|pink|Livewire"
  [codeigniter]="|peach|CodeIgniter"

  # --------------------------------------------------------------------------
  # Tools
  # --------------------------------------------------------------------------

  [tailwind3]="󱏿|sky|Tailwind CSS v3"
  [tailwind4]="󱏿|teal|Tailwind CSS v4"
  [shadcn]="󰔎|text|shadcn/ui"
  [prisma]="|lavender|Prisma"

  # --------------------------------------------------------------------------
  # Runtime
  # --------------------------------------------------------------------------

  [node]="󰎙|green|Node.js"
  [bun]="|peach|Bun"
  [deno]="|text|Deno"
  [php]="|mauve|PHP"
  [python]="|yellow|Python"

  # --------------------------------------------------------------------------
  # Package Manager
  # --------------------------------------------------------------------------

  [pnpm]="󰋁|blue|pnpm"
  [bun - pm]="|peach|bun"
  [yarn]="󰄛|sky|Yarn"
  [npm]="|red|npm"
)

# ==============================================================================
# Composition Registry
#
# Renderer hanya membaca registry ini.
# Renderer tidak mengetahui icon, warna maupun label.
# ==============================================================================

declare -Ar COMPOSITIONS=(

  # --------------------------------------------------------------------------
  # Frontend
  # --------------------------------------------------------------------------

  [next]="next"
  [astro]="astro"
  [nuxt]="nuxt"
  [react]="react"
  [vue]="vue"

  [vite - react]="vite react"
  [vite - vue]="vite vue"

  # --------------------------------------------------------------------------
  # Backend
  # --------------------------------------------------------------------------

  [laravel]="laravel"

  [laravel - livewire]="laravel livewire"

  [laravel - inertia - react]="laravel inertia react"

  [laravel - inertia - vue]="laravel inertia vue"

  [codeigniter]="codeigniter"
)

# ==============================================================================
# Global State
# ==============================================================================

FRONTEND=""
BACKEND=""
BACKEND_VARIANT=""
PACKAGE_MANAGER=""

declare -A TOOLS=()
declare -A RUNTIMES=()

# ==============================================================================
# Common Constants
# ==============================================================================

PACKAGE_JSON="package.json"
COMPOSER_JSON="composer.json"

TAILWIND_V3="3"
TAILWIND_V4="4"

# ==============================================================================
# Utility Functions
# ==============================================================================

##
# Memeriksa apakah file tersedia.
#
# @param {string} file Nama file.
# @return {number} 0 jika ada, selain itu 1.
#
has_file() {
  [[ -f "$1" ]]
}

##
# Memeriksa apakah direktori tersedia.
#
# @param {string} dir Nama direktori.
# @return {number} 0 jika ada, selain itu 1.
#
has_dir() {
  [[ -d "$1" ]]
}

##
# Memeriksa dependency pada package.json menggunakan jq.
#
# @param {string} package Nama package.
# @return {number} 0 jika ditemukan.
#
has_pkg() {

  has_file "$PACKAGE_JSON" || return 1

  jq -e \
    --arg pkg "$1" \
    '
        (
            .dependencies // {}
        ) + (
            .devDependencies // {}
        ) | has($pkg)
        ' \
    "$PACKAGE_JSON" \
    >/dev/null 2>&1
}

##
# Memeriksa dependency pada composer.json menggunakan jq.
#
# @param {string} package Nama package.
# @return {number} 0 jika ditemukan.
#
has_composer() {

  has_file "$COMPOSER_JSON" || return 1

  jq -e \
    --arg pkg "$1" \
    '
        (
            .require // {}
        ) + (
            .["require-dev"] // {}
        ) | has($pkg)
        ' \
    "$COMPOSER_JSON" \
    >/dev/null 2>&1
}

# ==============================================================================
# ANSI Color Mapping (Catppuccin Mocha)
# ==============================================================================

# Kita pakai hash array supaya pencarian warna instan dan akurat
declare -A COLORS=(
  [red]="\033[38;2;243;139;168m"
  [mauve]="\033[38;2;203;166;247m"
  [green]="\033[38;2;166;227;161m"
  [yellow]="\033[38;2;249;226;175m"
  [peach]="\033[38;2;250;179;135m"
  [sky]="\033[38;2;137;220;235m"
  [teal]="\033[38;2;148;226;213m" # Ditambahkan untuk Tailwind v4!
  [sapphire]="\033[38;2;116;199;236m"
  [blue]="\033[38;2;137;180;250m" # Ditambahkan untuk pnpm!
  [lavender]="\033[38;2;180;190;254m"
  [pink]="\033[38;2;245;194;231m"
  [text]="\033[38;2;205;214;244m"
  [reset]="\033[0m"
)

style() {
  local color_key="$1"
  local text="$2"

  # Ambil kode warna, kalau salah ketik otomatis dikembalikan ke warna default
  local color_code="${COLORS[$color_key]:-\033[0m}"

  # Menggunakan %b agar \033 tereksekusi sempurna sebagai escape character
  printf "%b%s%b" "$color_code" "$text" "${COLORS[reset]}"
}

render() {
  local key="$1"

  # Cek apakah key benar-benar eksis
  [[ -v "META[$key]" ]] || return 1

  local value="${META[$key]}"

  # Ekstrak data TANPA menggunakan <<< agar terhindar dari invisible newline
  local icon="${value%%|*}"
  local rest="${value#*|}"
  local color="${rest%%|*}"
  local label="${rest#*|}"

  style "$color" "$icon $label"
}

##
# Merender sebuah komposisi berdasarkan registry COMPOSITIONS.
#
# @param {string} key Composition key.
# @return {string}
#
render_composition() {

  local key="$1"

  local items=()
  local component

  for component in ${COMPOSITIONS[$key]}; do
    items+=("$(render "$component")")
  done

  join_by " " "${items[@]}"
}

##
# Menggabungkan array menggunakan separator tertentu.
#
# @param {string} separator
# @param {...string} values
# @return {string}
#
join_by() {

  local separator="$1"

  shift

  local first=1

  local item

  for item in "$@"; do

    if ((first)); then
      printf '%s' "$item"
      first=0
    else
      printf '%s%s' "$separator" "$item"
    fi

  done
}

# ==============================================================================
# Detection Layer
# ==============================================================================

##
# Mendeteksi frontend framework.
#
# Priority:
#   1. Next.js
#   2. Astro
#   3. Nuxt
#   4. Vite + React
#   5. Vite + Vue
#   6. React
#   7. Vue
#
# @return {void}
#
detect_frontend() {

  FRONTEND=""

  has_pkg "next" && {
    FRONTEND="next"
    return
  }

  has_pkg "astro" && {
    FRONTEND="astro"
    return
  }

  has_pkg "nuxt" && {
    FRONTEND="nuxt"
    return
  }

  if has_pkg "vite"; then

    if has_pkg "react"; then
      FRONTEND="vite-react"
      return
    fi

    if has_pkg "vue"; then
      FRONTEND="vite-vue"
      return
    fi
  fi

  has_pkg "react" && {
    FRONTEND="react"
    return
  }

  has_pkg "vue" && {
    FRONTEND="vue"
  }
}

##
# Mendeteksi backend framework beserta variannya.
#
# Supported:
#   - Laravel
#   - Laravel + Inertia React
#   - Laravel + Inertia Vue
#   - Laravel + Livewire
#   - CodeIgniter
#
# @return {void}
#
detect_backend() {

  BACKEND=""
  BACKEND_VARIANT=""

  if has_file "artisan" && has_composer "laravel/framework"; then

    BACKEND="laravel"

    if has_composer "livewire/livewire"; then
      BACKEND_VARIANT="livewire"
      return
    fi

    if has_composer "inertiajs/inertia-laravel"; then

      if has_pkg "@inertiajs/react"; then
        BACKEND_VARIANT="inertia-react"
        return
      fi

      if has_pkg "@inertiajs/vue3"; then
        BACKEND_VARIANT="inertia-vue"
        return
      fi

    fi

    return
  fi

  if has_file "spark" || has_file "app/Config/App.php"; then

    if has_composer "codeigniter4/framework"; then
      BACKEND="codeigniter"
      return
    fi

  fi
}

##
# Mendeteksi tools pendukung project.
#
# Supported:
#   - Tailwind CSS v3
#   - Tailwind CSS v4
#   - shadcn/ui
#   - Prisma
#
# @return {void}
#
detect_tools() {

  TOOLS=()

  if has_pkg "tailwindcss"; then

    local version

    version="$(
      jq -r '
                (
                    .dependencies.tailwindcss //
                    .devDependencies.tailwindcss //
                    ""
                )
            ' "$PACKAGE_JSON"
    )"

    if [[ "$version" =~ ^\^?4 ]]; then
      TOOLS[tailwind]="$TAILWIND_V4"
    else
      TOOLS[tailwind]="$TAILWIND_V3"
    fi

  fi

  has_pkg "shadcn-ui" &&
    TOOLS[shadcn]=1

  has_pkg "@prisma/client" &&
    TOOLS[prisma]=1

  has_pkg "prisma" &&
    TOOLS[prisma]=1
}

##
# Mendeteksi runtime yang digunakan project.
#
# Supported:
#   - Node.js
#   - Bun
#   - Deno
#   - PHP
#   - Python
#
# @return {void}
#
detect_runtime() {

  RUNTIMES=()

  has_file "$PACKAGE_JSON" &&
    RUNTIMES[node]=1

  has_file "bun.lockb" &&
    RUNTIMES[bun]=1

  has_file "bun.lock" &&
    RUNTIMES[bun]=1

  has_file "deno.json" &&
    RUNTIMES[deno]=1

  has_file "deno.jsonc" &&
    RUNTIMES[deno]=1

  has_file "$COMPOSER_JSON" &&
    RUNTIMES[php]=1

  has_file "pyproject.toml" &&
    RUNTIMES[python]=1

  has_file "requirements.txt" &&
    RUNTIMES[python]=1

  has_file "Pipfile" &&
    RUNTIMES[python]=1

  has_file "poetry.lock" &&
    RUNTIMES[python]=1
}

##
# Mendeteksi package manager.
#
# Priority:
#   1. Field "packageManager" di package.json
#   2. pnpm-lock.yaml
#   3. bun.lock / bun.lockb
#   4. yarn.lock
#   5. package-lock.json
#
# @return {void}
#
detect_package_manager() {

  PACKAGE_MANAGER=""

  # 1. Prioritas Utama: Cek spesifikasi Corepack di package.json
  if has_file "$PACKAGE_JSON"; then
    local pm_field
    # Ambil value dari "packageManager", abaikan error jika file tidak valid
    pm_field="$(jq -r '.packageManager // empty' "$PACKAGE_JSON" 2>/dev/null)"

    if [[ "$pm_field" == pnpm* ]]; then
      PACKAGE_MANAGER="pnpm"
      return
    elif [[ "$pm_field" == bun* ]]; then
      PACKAGE_MANAGER="bun-pm"
      return
    elif [[ "$pm_field" == yarn* ]]; then
      PACKAGE_MANAGER="yarn"
      return
    elif [[ "$pm_field" == npm* ]]; then
      PACKAGE_MANAGER="npm"
      return
    fi
  fi

  # 2. Fallback: Cek Lockfile jika packageManager tidak diset
  has_file "pnpm-lock.yaml" && {
    PACKAGE_MANAGER="pnpm"
    return
  }

  if has_file "bun.lockb" || has_file "bun.lock"; then
    PACKAGE_MANAGER="bun-pm"
    return
  fi

  has_file "yarn.lock" && {
    PACKAGE_MANAGER="yarn"
    return
  }

  has_file "package-lock.json" && {
    PACKAGE_MANAGER="npm"
    return
  }
}

# ==============================================================================
# Rendering Layer
# ==============================================================================

##
# Merender frontend.
#
# @return {string}
#
render_frontend() {

  [[ -n "$FRONTEND" ]] || return 0

  render_composition "$FRONTEND"
}

##
# Merender backend.
#
# @return {string}
#
render_backend() {

  [[ -n "$BACKEND" ]] || return 0

  local composition="$BACKEND"

  [[ -n "$BACKEND_VARIANT" ]] && composition="${BACKEND}-${BACKEND_VARIANT}"

  render_composition "$composition"
}

##
# Merender tools.
#
# @return {string}
#
render_tools() {

  local items=()

  if [[ "${TOOLS[tailwind]:-}" == "$TAILWIND_V3" ]]; then
    items+=("$(render tailwind3)")
  fi

  if [[ "${TOOLS[tailwind]:-}" == "$TAILWIND_V4" ]]; then
    items+=("$(render tailwind4)")
  fi

  local order=(
    shadcn
    prisma
  )

  local tool

  for tool in "${order[@]}"; do

    [[ -n "${TOOLS[$tool]:-}" ]] || continue

    items+=("$(render "$tool")")

  done

  join_by " " "${items[@]}"
}

##
# Merender runtime.
#
# @return {string}
#
render_runtime() {

  local order=(
    node
    bun
    deno
    php
    python
  )

  local items=()

  local runtime

  for runtime in "${order[@]}"; do

    [[ -n "${RUNTIMES[$runtime]:-}" ]] || continue

    items+=("$(render "$runtime")")

  done

  join_by " " "${items[@]}"
}

##
# Merender package manager.
#
# @return {string}
#
render_package_manager() {

  [[ -n "$PACKAGE_MANAGER" ]] || return 0

  render "$PACKAGE_MANAGER"
}

render_output() {
  local backend frontend tools runtime package_manager
  local -a sections=()

  backend="$(render_backend)"
  [[ -n "$backend" ]] && sections+=("$backend")

  frontend="$(render_frontend)"
  [[ -n "$frontend" ]] && sections+=("$frontend")

  tools="$(render_tools)"
  [[ -n "$tools" ]] && sections+=("$tools")

  runtime="$(render_runtime)"
  [[ -n "$runtime" ]] && sections+=("$runtime")

  package_manager="$(render_package_manager)"
  [[ -n "$package_manager" ]] && sections+=("$package_manager")

  if ((${#sections[@]} == 0)); then
    return 1
  fi

  # Render garis awal menggunakan hash array COLORS
  printf '%b%b%s\n' "${COLORS[green]}" "${COLORS[reset]}" "$(join_by " ⋄ " "${sections[@]}")"
}

# ==============================================================================
# Main
# ==============================================================================

##
# Entry point.
#
# @return {number}
#
main() {

  detect_frontend
  detect_backend
  detect_tools
  detect_runtime
  detect_package_manager

  render_output
}

main "$@"
