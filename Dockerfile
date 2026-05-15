# ─── Stage 1: Build ──────────────────────────────────────────────────────────
FROM hexpm/elixir:1.18.4-erlang-27.1.2-debian-bookworm-20260505-slim AS builder

RUN apt-get update -y && \
    apt-get install -y build-essential git curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

# Install hex & rebar
RUN mix local.hex --force && mix local.rebar --force

# Cache deps terpisah agar layer ini tidak rebuild saat code berubah
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy config sebelum compile (dibutuhkan oleh beberapa deps)
COPY config config/
COPY priv priv/
COPY lib lib/
COPY assets assets/

# Build assets (tailwind & esbuild diunduh otomatis oleh mix)
RUN mix assets.build
RUN mix assets.deploy

# Compile aplikasi & buat release
RUN mix compile
RUN mix release

# ─── Stage 2: Runtime ────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS runner

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set locale UTF-8
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

RUN useradd --uid 1000 --create-home deploy
USER deploy

# Salin release dari stage builder
COPY --from=builder --chown=deploy:deploy /app/_build/prod/rel/forum_aws_rekognition ./

ENV PHX_SERVER=true
ENV PORT=4000

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

CMD ["bin/forum_aws_rekognition", "start"]
