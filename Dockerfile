FROM ruby:3.4.8-bookworm

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    postgresql-client \
    libvips \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# 追加: ビルド時にアセットを事前コンパイル（ENVを永続化しない）
RUN RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# 追加: 本番環境として起動（Render側で環境変数を設定してもOK）
ENV RAILS_ENV=production
ENV RACK_ENV=production

# 修正: Render は PORT を渡す（既定は 10000）ので、それを使う :contentReference[oaicite:0]{index=0}
CMD ["bash", "-lc", "rm -f tmp/pids/server.pid && bin/rails s -b 0.0.0.0 -p ${PORT:-3000}"]
