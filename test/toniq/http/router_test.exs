defmodule Toniq.Http.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @router Toniq.Http.Router
  @opts @router.init([])

  test "/status shows the status page" do
    conn = conn(:get, "/status")
    |> @router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body =~ "Toniq Status"
    assert conn.resp_body =~ "http://localhost:4000"
  end

  test "returns a 404 when resource does not exists" do
    conn = conn(:get, "/not_existing")
    |> @router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body == ""
  end

  describe "/api/failed_jobs" do
    import Mox

    setup do
      start_supervised Mox.Server
      :ok
    end

    test "returns an empty list when there are no failing jobs" do
      expect(ToniqMock, :failed_jobs, fn() -> [] end)

      conn = conn(:get, "/api/failed_jobs")
      |> @router.call(@opts)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "[]"

      verify! ToniqMock
    end

    test "returns a list with all failing jobs" do
      failing_job = %{arguments: :fail,
                      error: %RuntimeError{message: "failing every time"},
                      id: 1,
                      version: 1,
                      vm: "ffded580-dab6-11e7-a87d-089e01388fa2",
                      worker: Toniq.TestWorker}

      expect(ToniqMock, :failed_jobs, fn() -> [failing_job] end)

      conn = conn(:get, "/api/failed_jobs")
      |> @router.call(@opts)


      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "[{\"worker\":\"Elixir.Toniq.TestWorker\",\"vm\":\"ffded580-dab6-11e7-a87d-089e01388fa2\",\"version\":1,\"id\":1,\"error\":{\"message\":\"failing every time\",\"__exception__\":true},\"arguments\":\"fail\"}]"
    end
  end
end
