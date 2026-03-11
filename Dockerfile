ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3
ARG ALPINE_VERSION=3.21.3

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

# Build stage
FROM ${BUILDER_IMAGE} AS builder

RUN apk add --no-cache build-base git nodejs npm

WORKDIR /app

ENV MIX_ENV="prod"

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/runtime.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN cd assets && npm install
RUN mix assets.deploy
RUN mix compile

RUN mix release

# Runtime stage
FROM ${RUNNER_IMAGE}

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

ENV MIX_ENV="prod"

COPY --from=builder /app/_build/${MIX_ENV}/rel/survey_pulse ./

RUN chown -R nobody:nobody /app
USER nobody

ENV PHX_SERVER=true
ENV PORT=4600

EXPOSE 4600

CMD ["/app/bin/server"]
