
## Getting Started with JFrog Curation for Ruby 
As per the original [README](README-original.md) :
To begin, if you do not have Ruby  we suggest
using this [site](https://gorails.com/setup) to install the software.
Pick the appropriate operating system and follow the instructions.

### Installing Ruby
First, we need to install Ruby's dependencies using Homebrew.
```
brew install openssl@3 libyaml gmp rust
```
I tried to  install Ruby using a version manager called [Mise](https://mise.jdx.dev/getting-started.html) and [rbenv](https://github.com/rbenv/rbenv). This allows you to easily update Ruby and switch between versions anytime.
But both of them failed on my mac even after I fixed the ssl handshake issue during download and also dis the following:
First, update your SSL certificates using Homebrew:
```
brew update
brew reinstall ca-certificates
brew install binutils
export PATH="$(brew --prefix binutils)/bin:$PATH"
```
So installed using:

```
brew install ruby
echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
gem install bundler
```

Confirm that Ruby is installed and works:
```
ruby --version

Output: 
ruby 3.4.2 (2025-02-15 revision d2930f8e7a) +PRISM [x86_64-darwin23]
```
Configure the environment variables used in the [Gemfile](Gemfile).
This way, the values are retrieved from environment variables at runtime when Bundler processes the Gemfile:
```
export MY_ACCESS_TOKEN=myaccesstoken
export MYUSER=username
export MYSERVER=example.jfrog.io
```
Also in Gemfile set :
```
ruby "3.4.2"
``` 

You can regenerate the Gemfile.lock wiht the new "remote" , "RUBY VERSION" and  "BUNDLED WITH":
```
bundle lock
or
bundle lock --update
```

Now you can generate the "scripts/dependency_tree.json" from the Gemfile.lock using:
```
ruby scripts/parse_gemfile_lock.rb
```

Resolve the dependencies via JFrog Curation enabled Repository using HTTP HEAD request:
```
ruby scripts/parse_gemfile_lock_curation_audit_HEAD_req.rb "https://$MYSERVER/artifactory/api/gems/cg-lab-ruby-gems-remote/gems" "$MY_ACCESS_TOKEN"
```

Download the dependencies via JFrog Curation enabled Repository using HTTP GET request to the "scripts/downloaded_gems" folder:
```
ruby scripts/parse_gemfile_lock_curation_audit_DOWNLOAD_req.rb "https://$MYSERVER/artifactory/api/gems/cg-lab-ruby-gems-remote/gems" "$MY_ACCESS_TOKEN"
```

Configure bundler and Install Dependencies:

1: Configure Bundler
```
bundle config set path 'vendor/bundle'
bundle config set without 'development test'
```
2: Install Dependencies with the  Bundler but it will exit in the first dependency that Curation blocks:
```
bundle install --retry=1
```


