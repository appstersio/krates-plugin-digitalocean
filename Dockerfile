FROM ruby:2.4.1

WORKDIR /src/app

ADD . .

RUN gem update --system 3.0.4 && bundle install

ENTRYPOINT [ "/bin/bash" ]