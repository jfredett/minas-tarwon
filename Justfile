set dotenv-load

[private]
@default:
  just --list

import "just/update.just"
import "just/show.just"
import "just/deploy.just"
import "just/utility.just"
import "just/git.just"
import "just/cert.just"
