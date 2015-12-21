# 열린옷장 자원봉사 #

열린옷장의 자원봉사에 관한 서비스입니다.

# 설치 및 실행 #

    $ cpanm --installdeps .
    $ bower install
    $ cp volunteer.conf.sample volunteer.conf
    $ MOJO_CONFIG=volunteer.conf morbo -l 'http://*:5000' ./script/volunteer    # http://localhost:5000


## docs ##

    $ npm install -g grunt-cli
    $ npm install
    $ gem install bundler
    $ bundle install
    $ bundle exec jekyll serve    # http://localhost:5000

# 환경변수 #

- OPENCLOSET_APISTORE_ID
- OPENCLOSET_APISTORE_API_STORE_KEY
- OPENCLOSET_GOOGLE_PRIVATE_KEY

google private key 는 암호화된 JSON Web Token 파일입니다.
자세한 내용은 [Service Account](https://developers.google.com/identity/protocols/OAuth2ServiceAccount)를 참고.
