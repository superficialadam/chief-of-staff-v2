# syntax=docker/dockerfile:1
# check=error=true

# Make sure RUBY_VERSION matches your .ruby-version
ARG RUBY_VERSION=3.3.6
# Bump to force cache busts when iterating
ARG CACHE_BUSTER=1

########################
# Base — runtime image #
########################
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base
WORKDIR /rails

# Runtime libs incl. PostgreSQL runtime for pg gem
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      sqlite3 \
      libpq5 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Production bundler/Rails env
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

#######################
# Build — compile stage
#######################
FROM docker.io/library/ruby:$RUBY_VERSION AS build
WORKDIR /rails

# Production bundler/Rails env
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# Build deps for native gems + Node for asset builds (if using js/css bundling)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libyaml-dev \
      pkg-config \
      libpq-dev \
      nodejs \
      npm && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install gems first for better caching
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# If bootsnap is present in the bundle, precompile its caches for gems
RUN bundle info bootsnap >/dev/null 2>&1 && bundle exec bootsnap precompile --gemfile || true

# Copy app code
COPY . .

# If bootsnap is present, precompile app/lib caches (optional optimization)
RUN bundle info bootsnap >/dev/null 2>&1 && bundle exec bootsnap precompile --app || true

# If using js/css bundling these will no-op when no package.json
RUN test -f package.json && npm ci || true
RUN test -f package.json && npm run build || true

# Precompile Rails assets WITHOUT real master key
RUN SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile

############################
# Debug stage (optional, for fast local investigation)
############################
FROM build AS debug
CMD ["/bin/bash"]

#######################
# Final — production image
#######################
FROM base
COPY --from=build ${BUNDLE_PATH} ${BUNDLE_PATH}
COPY --from=build /rails /rails

# Non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash rails && \
    chown -R rails:rails db log storage tmp
USER rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
