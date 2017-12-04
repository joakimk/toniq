defmodule Toniq.Http.Router do
  use Plug.Router

  @toniq Application.get_env(:toniq, :http_toniq)

  plug :match
  plug :dispatch

  get "/status" do
    http_port = Application.get_env(:toniq, :http_port)
    api_endpoint = "http://localhost:" <> to_string(http_port)

    status_page = render("status.html", [api_endpoint: api_endpoint])

    send_resp(conn, 200, status_page)
  end

  get "/api/failed_jobs" do
    failed_jobs = @toniq.failed_jobs

    send_resp(conn, 200, Poison.encode!(failed_jobs))
  end

  match _ do
    send_resp(conn, 404, "")
  end

  defp render(template, arguments) do
    templates = "lib/toniq/http/templates/"
    EEx.eval_file(templates <> template <> ".eex", arguments)
  end
end
