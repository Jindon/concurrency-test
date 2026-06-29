defmodule ConcurrencyTest.ConfigTest do
  use ExUnit.Case, async: true

  alias ConcurrencyTest.Config
  alias ConcurrencyTest.Config.{RunConfig, RequestConfig, Scenario}

  test "loads a valid YAML file into a Scenario struct" do
    assert {:ok, %Scenario{} = s} = Config.load("test/fixtures/valid.yml")
    assert s.name == "Test Scenario"
    assert %RunConfig{requests: 10, concurrency: 2, timeout: 5000} = s.run
    assert %RequestConfig{method: "POST", url: "http://localhost:8000/test"} = s.request
    assert s.headers["Authorization"] == "Bearer abc"
    assert s.body["amount"] == 100
  end

  test "returns error for missing file" do
    assert {:error, msg} = Config.load("no_such_file.yml")
    assert msg =~ "not found"
  end

  test "returns error when run section is missing" do
    assert {:error, msg} = Config.load("test/fixtures/missing_run.yml")
    assert msg =~ "run"
  end

  test "returns error for invalid HTTP method" do
    assert {:error, msg} = Config.load("test/fixtures/invalid_method.yml")
    assert msg =~ "Invalid HTTP method"
  end

  test "normalises method to uppercase" do
    raw = %{
      "name" => "x",
      "run" => %{"requests" => 1, "concurrency" => 1, "timeout" => 1000},
      "request" => %{"method" => "post", "url" => "http://example.com"}
    }

    assert {:ok, s} = Config.load_from_map(raw)
    assert s.request.method == "POST"
  end
end

defmodule ConcurrencyTest.TemplateTest do
  use ExUnit.Case, async: true

  alias ConcurrencyTest.Template

  test "renders {{uuid}} as a valid UUID v4" do
    result = Template.render("{{uuid}}")
    assert String.match?(result, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
  end

  test "each {{uuid}} produces a different value" do
    [a, b, c] = for _ <- 1..3, do: Template.render("{{uuid}}")
    assert a != b
    assert b != c
  end

  test "renders multiple placeholders in one string" do
    result = Template.render("{{uuid}}-{{uuid}}")
    [left, right] = String.split(result, "-", parts: 2)
    # each half is independently unique
    refute left == right
  end

  test "traverses nested maps" do
    input = %{"a" => %{"b" => "{{uuid}}"}}
    %{"a" => %{"b" => uuid}} = Template.render(input)
    assert String.match?(uuid, ~r/^[0-9a-f]{8}-/)
  end

  test "traverses lists" do
    [a, b] = Template.render(["{{uuid}}", "{{uuid}}"])
    assert a != b
  end

  test "passes through unknown placeholders" do
    assert Template.render("{{unknown}}") == "{{unknown}}"
  end

  test "passes through non-string values unchanged" do
    assert Template.render(42) == 42
    assert Template.render(true) == true
    assert Template.render(nil) == nil
  end
end

defmodule ConcurrencyTest.ReportTest do
  use ExUnit.Case, async: true

  alias ConcurrencyTest.Report

  test "percentile of empty list is 0" do
    assert Report.percentile([], 95) == 0
  end

  test "p100 of a single-element list is that element" do
    assert Report.percentile([42], 99) == 42
  end

  test "p50 of sorted list" do
    list = Enum.to_list(1..100)
    assert Report.percentile(list, 50) == 50
  end

  test "p95 of 100-element list" do
    list = Enum.to_list(1..100)
    assert Report.percentile(list, 95) == 95
  end

  test "p99 of 100-element list" do
    list = Enum.to_list(1..100)
    assert Report.percentile(list, 99) == 99
  end

  test "print/4 produces output without crashing" do
    metrics = %ConcurrencyTest.Metrics{
      total: 3,
      success: 2,
      failure: 1,
      status_codes: %{200 => 2},
      latencies: [10, 20, 30],
      started_at: 0,
      finished_at: 1000
    }

    output = ExUnit.CaptureIO.capture_io(fn -> Report.print("Test", 3, 2, metrics) end)
    assert output =~ "Test"
    assert output =~ "Success:       2"
    assert output =~ "Failure:       1"
    assert output =~ "200 : 2"
    assert output =~ "RPS"
  end
end
