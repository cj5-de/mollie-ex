defmodule MollieEx.Resources.OptionsTest do
  use ExUnit.Case, async: true

  alias MollieEx.Resources.Options

  describe "query/1" do
    test "builds query keywords from non-nil values" do
      query = Options.query(from: "tr_123", limit: nil, sort: "desc", testmode: false)

      assert query[:from] == "tr_123"
      assert query[:sort] == "desc"
      assert query[:testmode] == false
      refute Keyword.has_key?(query, :limit)
    end

    test "preserves existing put_query ordering semantics" do
      assert Options.query(from: "tr_123", limit: 10, sort: "asc") == [
               sort: "asc",
               limit: 10,
               from: "tr_123"
             ]
    end
  end
end
