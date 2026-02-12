local helpers = require("diffview.tests.helpers")

local eq = helpers.eq

describe("diffview.vcs.adapters.jj", function()
  local JjAdapter = require("diffview.vcs.adapters.jj").JjAdapter
  local RevType = require("diffview.vcs.rev").RevType
  local arg_parser = require("diffview.arg_parser")

  ---@return JjAdapter
  local function new_adapter()
    local old_get_dir = JjAdapter.get_dir
    JjAdapter.get_dir = function(_)
      return "/tmp/.jj"
    end

    local adapter = JjAdapter({
      toplevel = "/tmp",
      path_args = {},
      cpath = nil,
    })

    JjAdapter.get_dir = old_get_dir

    local rev_map = {
      ["@"] = "head_hash",
      ["main"] = "main_hash",
      ["feature"] = "feature_hash",
    }

    adapter.resolve_rev_arg = function(_, rev)
      return rev_map[rev]
    end

    adapter.head_rev = function(_)
      return adapter.Rev(RevType.COMMIT, rev_map["@"] or "head_hash", true)
    end

    adapter.symmetric_diff_revs = function(_, _)
      return adapter.Rev(RevType.COMMIT, "merge_base_hash"), adapter.Rev(RevType.COMMIT, rev_map["@"])
    end

    return adapter
  end

  describe("parse_revs()", function()
    it("defaults to HEAD..LOCAL when no rev is provided", function()
      local adapter = new_adapter()
      local left, right = adapter:parse_revs(nil, {})

      eq(RevType.COMMIT, left.type)
      eq("head_hash", left.commit)
      eq(RevType.LOCAL, right.type)
    end)

    it("parses single rev as COMMIT..LOCAL", function()
      local adapter = new_adapter()
      local left, right = adapter:parse_revs("main", {})

      eq(RevType.COMMIT, left.type)
      eq("main_hash", left.commit)
      eq(RevType.LOCAL, right.type)
    end)

    it("parses double-dot range as COMMIT..COMMIT", function()
      local adapter = new_adapter()
      local left, right = adapter:parse_revs("main..feature", {})

      eq(RevType.COMMIT, left.type)
      eq("main_hash", left.commit)
      eq(RevType.COMMIT, right.type)
      eq("feature_hash", right.commit)
    end)

    it("parses triple-dot range through symmetric merge-base resolution", function()
      local adapter = new_adapter()
      local left, right = adapter:parse_revs("main...@", {})

      eq(RevType.COMMIT, left.type)
      eq("merge_base_hash", left.commit)
      eq(RevType.COMMIT, right.type)
      eq("head_hash", right.commit)
    end)
  end)

  describe("diffview_options()", function()
    it("accepts --selected-file and resolves rev args", function()
      local adapter = new_adapter()
      local argo = arg_parser.parse({ "main", "--selected-file=lua/diffview/init.lua" })
      local opt = adapter:diffview_options(argo)

      eq("main_hash", opt.left.commit)
      eq(RevType.LOCAL, opt.right.type)
      eq("lua/diffview/init.lua", opt.options.selected_file)
    end)
  end)

  describe("rev_to_args()", function()
    it("returns --from/--to for commit ranges", function()
      local adapter = new_adapter()
      local args = adapter:rev_to_args(
        adapter.Rev(RevType.COMMIT, "left_hash"),
        adapter.Rev(RevType.COMMIT, "right_hash")
      )

      eq({ "--from", "left_hash", "--to", "right_hash" }, args)
    end)

    it("returns --from for commit..LOCAL", function()
      local adapter = new_adapter()
      local args = adapter:rev_to_args(
        adapter.Rev(RevType.COMMIT, "left_hash"),
        adapter.Rev(RevType.LOCAL)
      )

      eq({ "--from", "left_hash" }, args)
    end)
  end)
end)
