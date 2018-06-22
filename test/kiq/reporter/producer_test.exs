defmodule Kiq.Reporter.ProducerTest do
  use Kiq.Case, async: true

  alias Kiq.EchoConsumer, as: Consumer
  alias Kiq.Reporter.Producer

  test "buffered messages are dispatched to consumers" do
    {:ok, pro} = start_supervised({Producer, []})
    {:ok, _cn} = start_supervised({Consumer, subscribe_to: [pro], test_pid: self()})

    job_a = job()
    job_b = job()

    assert :ok = Producer.started(pro, job_a)
    assert :ok = Producer.success(pro, job_a, timing: 100)
    assert :ok = Producer.failure(pro, job_b, %RuntimeError{}, [])
    assert :ok = Producer.stopped(pro, job_a)

    assert_receive {:started, ^job_a}
    assert_receive {:success, ^job_a, [timing: 100]}
    assert_receive {:failure, ^job_b, %RuntimeError{}, []}
    assert_receive {:stopped, ^job_a}

    :ok = stop_supervised(Consumer)
    :ok = stop_supervised(Producer)
  end
end
