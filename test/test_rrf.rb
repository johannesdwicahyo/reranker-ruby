# frozen_string_literal: true

require "test_helper"

class TestRRF < Minitest::Test
  def test_fuse_single_list
    result = RerankerRuby::RRF.fuse(["a", "b", "c"])
    assert_equal ["a", "b", "c"], result
  end

  def test_fuse_two_lists
    list1 = ["a", "b", "c"]
    list2 = ["b", "a", "d"]

    result = RerankerRuby::RRF.fuse(list1, list2, k: 60)

    # "a" and "b" appear in both lists, should be ranked highest
    assert_includes result[0..1], "a"
    assert_includes result[0..1], "b"
  end

  def test_fuse_preserves_all_ids
    list1 = ["a", "b"]
    list2 = ["c", "d"]

    result = RerankerRuby::RRF.fuse(list1, list2, k: 60)

    assert_equal 4, result.length
    assert_includes result, "a"
    assert_includes result, "b"
    assert_includes result, "c"
    assert_includes result, "d"
  end

  def test_fuse_empty_lists
    result = RerankerRuby::RRF.fuse([], [])
    assert_equal [], result
  end

  def test_fuse_item_in_all_lists_ranks_first
    list1 = ["x", "a", "b"]
    list2 = ["y", "a", "c"]
    list3 = ["z", "a", "d"]

    result = RerankerRuby::RRF.fuse(list1, list2, list3, k: 60)

    assert_equal "a", result[0]
  end

  def test_fuse_with_custom_k
    list1 = ["a", "b"]
    list2 = ["b", "a"]

    result = RerankerRuby::RRF.fuse(list1, list2, k: 1)

    # With k=1, rank position matters more
    assert_equal 2, result.length
  end
end
