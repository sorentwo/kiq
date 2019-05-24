defmodule Kiq.EncoderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Kiq.Encoder

  defmodule Record do
    defstruct [:id, :meta]
  end

  def recode(term) do
    term
    |> Encoder.encode()
    |> Jason.decode!(keys: :atoms)
  end

  describe "encode/1" do
    test "structs are converted to maps" do
      assert recode(%Record{id: 1, meta: %{}}) == %{id: 1, meta: %{}}
    end

    test "nested structs are also encoded" do
      record_a = %Record{id: 1, meta: %{}}
      record_b = %Record{id: 2, meta: record_a}

      assert recode(record_b) == %{id: 2, meta: %{id: 1, meta: %{}}}
    end

    test "lists of terms are encoded" do
      record = %Record{id: 1, meta: %{}}

      assert recode([record]) == [%{id: 1, meta: %{}}]
    end

    test "types that can't be encoded are converted" do
      assert [[], _] = recode([{}, make_ref()])
    end

    property "un-encodable terms are safely converted to inspected values" do
      check all term <- one_of([tuple({tuple({string(:printable), integer()})})]) do
        assert <<value::binary>> = Encoder.encode(term)
      end
    end
  end
end
