defmodule Bench.Worker do
  use Kiq.Worker, queue: "bench"

  import Bench.Kiq, only: [bin_to_pid: 1]

  def perform([index, index, pid_bin]) do
    send(bin_to_pid(pid_bin), :finished)
  end

  def perform([index, total, _pid_bin]) do
    index * total
  end
end

enqueue_and_wait = fn total ->
  pid_bin = Bench.Kiq.pid_to_bin(self())

  for index <- 0..total do
    [index, total, pid_bin]
    |> Bench.Worker.new()
    |> Bench.Kiq.enqueue()
  end

  receive do
    :finished -> :ok
  after
    5_000 -> IO.puts "No message received"
  end
end

Benchee.run(
  %{"Enqueue & Perform" => enqueue_and_wait},
  inputs: %{"One Hundred Jobs" => 100},
  time: 10
)
