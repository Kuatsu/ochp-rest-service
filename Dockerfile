FROM ruby:3.1

WORKDIR /usr/src/app

COPY Gemfile ./
RUN bundle install

COPY . .

CMD ["ruby", "./src/main.rb"]
