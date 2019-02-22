workflow "New workflow" {
  on = "push"
  resolves = ["GitHub Action for AWS"]
}

action "GitHub Action for AWS" {
  uses = "actions/npm@3c8332795d5443adc712d30fa147db61fd520b5a"
  args = "install"
}
