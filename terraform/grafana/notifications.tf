resource "grafana_message_template" "rackman_slack" {
  name = "rackman-slack"
  template = <<-EOT
    {{ define "rackman.slack.title" -}}
    {{ if eq .Status "firing" }}🔴{{ else }}✅{{ end }} {{ .CommonLabels.alertname }}
    {{- end }}

    {{ define "rackman.slack.text" -}}
    {{ range .Alerts -}}
    {{ .Annotations.summary }}
    {{ end -}}
    {{- end }}
  EOT
}

resource "grafana_contact_point" "clarksons_slack" {
  name = "Clarksons Slack"

  slack {
    url                     = var.slack_webhook_url
    recipient               = "#rackman"
    title                   = "{{ template \"rackman.slack.title\" . }}"
    text                    = "{{ template \"rackman.slack.text\" . }}"
    disable_resolve_message = false
  }

  webhook {
    url                      = "http://ntfy.ntfy.svc/rackman"
    authorization_scheme     = "Bearer"
    authorization_credentials = var.ntfy_token
    message                  = "{{ if eq .Status \"firing\" }}🔴{{ else }}✅{{ end }} {{ .CommonLabels.alertname }}: {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
  }
}
