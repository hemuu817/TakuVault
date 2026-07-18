FROM ruby:3.4.8-bookworm

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    ripgrep \
    libpq-dev \
    postgresql-client \
    libvips \
    chromium \
    chromium-driver \
  && install -d /etc/apt/keyrings \
  && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
  && apt-get update -y \
  && apt-get install -y --no-install-recommends postgresql-client-18 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# 追加: ビルド時にアセットを事前コンパイル（ENVを永続化しない）
ARG BUILD_APP_HOST=localhost:3000
RUN RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 APP_HOST=${BUILD_APP_HOST} bundle exec rails assets:precompile

# 追加: 本番環境として起動（Render側で環境変数を設定してもOK）
ENV RAILS_ENV=production
ENV RACK_ENV=production

# 修正: Render は PORT を渡す（既定は 10000）ので、それを使う :contentReference[oaicite:0]{index=0}
CMD ["bash", "-lc", "rm -f tmp/pids/server.pid && bin/rails s -b 0.0.0.0 -p ${PORT:-3000}"]
