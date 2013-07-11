module Hiki2MW
  class Converter
    attr_accessor :source

    def initialize(source)
      @source = source
    end

    def convert
      source_converted = @source.dup

      source_converted.gsub!(/\r\n/, "\n")
      source_converted = minify_lfs(source_converted)

      source_converted = convert_in_block_before(source_converted)
      source_converted = convert_line_by_line(source_converted)
      source_converted = convert_in_block_after(source_converted)

      source_converted = minify_lfs(source_converted)

      source_converted
    end

    def self.get_link_re(name)
      /\[\[#{name}\]\]/
    end

    def self.get_plugin_re(name)
      /\{\{#{name}\}\}/
    end

    private_class_method :get_link_re, :get_plugin_re

    private

    def minify_lfs(str)
      str.sub(/\A\n+/, "").gsub(/\n{3,}/, "\n\n").chomp
    end

    BRACKET_LINK_RE = /\[\[.+?\]\]/
    URI_RE = /(?:https?|ftp|file|mailto):[A-Za-z0-9;\/?:@&=+$,\-_.!~*\'()#%]+/

    FORMAT_RE = {
      :pre => /^[ \t]/,
      :heading => /^!+/,
      :heading_comment => %r|^(//\s*)!+|,
      :quote => /^""/,
      :d_list => /^:/,
      :table => /^\|\|/
    }

    def determine_format(line)
      format = nil

      FORMAT_RE.each do |f, re|
        if re =~ line
          format = f
          break
        end
      end

      format
    end

    def convert_line_by_line(source)
      @lines = source.split("\n")

      headings_root = HeadingRoot.new
      @last_heading = headings_root
      @tables = []

      last_format = nil
      @lines.each_with_index do |line, i|
        format = determine_format(line)

        case format
        when :pre
          @lines[i] = (last_format != :pre ? "\n<pre>" : "") +
            line.sub(FORMAT_RE[:pre], "")
        when :quote
          @lines[i] = (last_format != :quote ? "\n<blockquote>\n" : "") +
            line.sub(FORMAT_RE[:quote], "")
        else
          case last_format
          when :pre
            @lines[i - 1] << "</pre>\n"
          when :quote
            @lines[i - 1] << "\n</blockquote>\n"
          end

          case format
          when :table
            if last_format != :table
              table = Table.new(i)
              table.rows << TableRow.new(line)
              @tables << table
            else
              @tables.last.rows << TableRow.new(line)
              @lines[i] = ""
            end
          when :heading
            append_heading Heading.new(i, line)
          when :heading_comment
            append_heading Heading.new(i, line, true)
          when :d_list
            convert_d_list i
          end
        end

        last_format = format
      end

      case last_format
      when :pre
        @lines.last << "</pre>"
      when :quote
        @lines.last << "\n</blockquote>"
      end

      unless headings_root.children.empty?
        headings_dfs(headings_root, 0)
      end

      convert_tables unless @tables.empty?

      @lines.join("\n")
    end

    def append_heading(heading)
      if heading.level > @last_heading.level
        parent_heading = @last_heading
      else
        parent_heading = @last_heading.parent
        while heading.level <= parent_heading.level
          break unless parent_heading.parent
          parent_heading = parent_heading.parent
        end
      end

      heading.append_to parent_heading
      @last_heading = heading
    end

    def headings_dfs(heading, depth)
      line_index = heading.line_index

      if line_index
        level_mw = "=" * (depth <= 5 ? depth + 1 : 6)
        source_mw = "\n" +
          (heading.comment ? "//" : "") +
          level_mw + " " +
          heading.content +
          " " + level_mw
        @lines[line_index] = source_mw
      end

      heading.children.each {|h| headings_dfs(h, depth + 1)}
    end

    def markup_span(column)
      rs = column.rowspan
      cs = column.colspan
      attributes = []
      markup = ""

      attributes << %Q(rowspan="#{rs}") if rs > 0
      attributes << %Q(colspan="#{cs}") if cs > 0

      markup = attributes.join(" ") + " | " unless attributes.empty?

      markup
    end

    def convert_tables
      @tables.each do |t|
        source_mw = %Q(\n{| class="wikitable"\n)

        t.rows.each do |r|
          source_mw << "|-\n"

          unless r.columns.empty?
            column = r.columns.shift
            is_heading = column.heading
            source_mw << (is_heading ? "! " : "| ") <<
              markup_span(column) << column.content
            last_is_heading = is_heading

            r.columns.each do |c|
              is_heading = c.heading
              if is_heading == last_is_heading
                source_mw << (is_heading ? " !! " : " || ")
              else
                source_mw << "\n" << (is_heading ? "! " : "| ")
              end

              source_mw << markup_span(c) << c.content

              last_is_heading = is_heading
            end

            source_mw << "\n"
          end
        end

        source_mw << "|}\n"

        @lines[t.line_index] = source_mw
      end
    end

    def convert_d_list(line_index)
      re = /\A((?:#{BRACKET_LINK_RE}|.)*?):/o
      str = @lines[line_index].sub(FORMAT_RE[:d_list], "")

      if str[0] == ":"
        @lines[line_index] = str
      else
        matches = re.match(str)
        if matches
          @lines[line_index] = ";" + matches[1] + "\n:" + matches.post_match
        else
          @lines[line_index] = ";" + str
        end
      end
    end

    PATTERNS_BEFORE = [
      [/==(.*?)==/, '<del>\1</del>'] # 取消線
    ]

    def convert_in_block_before(source)
      source_converted = source.dup
      PATTERNS_BEFORE.each do |re, replace_str|
        source_converted.gsub!(re, replace_str)
      end
      source_converted
    end

    PATTERNS_AFTER = [
      [get_plugin_re("toc"), ""], # {{toc}}
      [/^(\*#{get_link_re(/一覧:.+?/)})/, '//\1'], # [[一覧:]]
      [/^(\*#{get_link_re(/namazu:.+?/)})/, '//\1'], # [[namazu:]]
      [get_link_re(/(#{URI_RE})/), '\1'], # [[URI]]
      [get_link_re(/([^\]|]+)\|(#{URI_RE})/), '[\2 \1]'], # [[リンク名|URI]]
      [get_link_re(/([^\]|]+)\|(.*?)/), '[[\2|\1]]'], # [[リンク名|ページ名]]
      [get_plugin_re("br"), "<br />"], # {{br}}
      [get_plugin_re(/isbnImg\(?'([^']+)'\)?/), '<amazon>\1</amazon>'], # {{isbnImg''}}, {{isbnImg('')}}
      [%r!\n{2,}(//)!, "\\n\\1"], # コメント前の重複改行の除去
      [%r!^//(.*)!, '<!-- \1 -->'] # コメント
    ]

    def convert_in_block_after(source)
      source_converted = source.dup
      PATTERNS_AFTER.each do |re, replace_str|
        source_converted.gsub!(re, replace_str)
      end
      source_converted
    end

    class Heading
      attr_reader :parent, :children, :line_index, :level, :content, :comment

      def initialize(line_index, line, comment = false)
        @parent = nil
        @children = []
        @line_index = line_index

        if comment
          str_heading = line[FORMAT_RE[:heading_comment].match(line)[1].length..-1]
        else
          str_heading = line
        end

        matches = FORMAT_RE[:heading].match(str_heading)
        @level = matches[0].length
        @content = matches.post_match.gsub(/[ 　]+（/, "（")
        @comment = comment
      end

      def append_to(parent)
        @parent = parent
        parent.children << self

        self
      end
    end

    class HeadingRoot
      attr_reader :parent, :children, :line_index, :level

      def initialize
        @parent = nil
        @children = []

        @line_index = nil
        @level = 0
      end
    end

    class Table
      attr_reader :line_index, :rows

      def initialize(line_index)
        @line_index = line_index
        @rows = []
      end
    end

    class TableRow
      attr_reader :columns

      def initialize(line)
        @columns = []

        cols = line.sub(FORMAT_RE[:table], "").split("||")
        cols.each do |s|
          column = TableColumn.new

          if s[0] == "!"
            s = s[1..-1]
            column.heading = true
          end

          matches = /\A[\^>]+/.match(s)
          if matches
            column.content = matches.post_match
            span = matches[0]
            column.rowspan = count_span(span, "^")
            column.colspan = count_span(span, ">")
          else
            column.content = s
          end

          @columns << column
        end
      end

      private

      def count_span(str, ch)
        count = str.count(ch)

        count.zero? ? 0 : count + 1
      end
    end

    class TableColumn
      attr_accessor :content, :heading, :rowspan, :colspan

      def initialize
        @content = ""
        @heading = false
        @rowspan = 0
        @colspan = 0
      end
    end
  end
end
