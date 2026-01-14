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

CMD ["bash", "-c", "rm -f tmp/pids/server.pid && bin/rails s -b 0.0.0.0 -p 3000"]
