# encoding: utf-8

module Hiki2MW
  #
  # Hiki2MediaWiki リンク解析器
  #
  # Authors:: ocha
  # Version:: 2013-07-12
  #
  class LinkAnalyzer
    MODE_HIKI = 0
    MODE_MEDIAWIKI = 1

    def initialize(source, mode = Hiki2MW::LinkAnalyzer::MODE_MEDIAWIKI)
      unless mode == MODE_HIKI || mode == MODE_MEDIAWIKI
        raise ArgumentError.new("invalid analyzer mode")
      end

      self.source = source
      @mode = mode
    end

    def source
      @source
    end

    def source=(source)
      @source = source
      @lines = source.each_line
    end

    BRACKET_LINK_RE = /\[\[.+?\]\]/
    URI_RE = /(?:https?|ftp|file|mailto):[A-Za-z0-9;\/?:@&=+$,\-_.!~*\'()#%]+/
    WIKI_NAME_RE = /\b(?:[A-Z]+[a-z\d]+){2,}\b/
    WIKI_NAME_DET_RE_HIKI = /#{BRACKET_LINK_RE}|#{URI_RE}|#{WIKI_NAME_RE}/
    WIKI_NAME_DET_RE_MW = /#{BRACKET_LINK_RE}|\[#{URI_RE} .+?\]|#{URI_RE}|#{WIKI_NAME_RE}/

    def analyze
      result = {:alphabetical => [], :parened => [], :wikiname => []}

      @lines.with_index(1) do |l, line_num|
        # [[]] リンク
        char_index = 0
        while matches = BRACKET_LINK_RE.match(l, char_index)
          char_index = matches.pre_match.length
          char_num = char_index + 1
          content = matches[0][2..-3]

          if pipe_index = content.index("|")
            if @mode == MODE_HIKI
              page_name = content[(pipe_index + 1)..-1]
            elsif @mode == MODE_MEDIAWIKI
              page_name = content[0..(pipe_index - 1)]
            end
          else
            page_name = content
          end

          # 英字名ページへのリンク
          unless /[^ -~]/ =~ page_name
            result[:alphabetical] << {
              :line_num => line_num,
              :char_num => char_num,
              :link => matches[0],
              :page_name => page_name
            }
          end

          # 括弧を含む名前のページへのリンク
          if (page_name[-1] == ")" || page_name[-1] == "）") &&
              /[(（]/ =~ page_name
            result[:parened] << {
              :line_num => line_num,
              :char_num => char_num,
              :link => matches[0],
              :page_name => page_name
            }
          end

          char_index += matches[0].length + 1
        end

        # WikiName
        char_index = 0
        re = case @mode
             when MODE_HIKI
               WIKI_NAME_DET_RE_HIKI
             when MODE_MEDIAWIKI
               WIKI_NAME_DET_RE_MW
             end
        while matches = re.match(l, char_index)
          char_index = matches.pre_match.length
          char_num = char_index + 1

          unless matches[0][0] == "[" || URI_RE =~ matches[0]
            result[:wikiname] << {
              :line_num => line_num,
              :char_num => char_num,
              :link => matches[0],
              :page_name => matches[0]
            }
          end

          char_index += matches[0].length + 1
        end
      end

      result
    end
  end

  module_function
  def analyze_links_mw(source)
    Hiki2MW::LinkAnalyzer.new(source, Hiki2MW::LinkAnalyzer::MODE_MEDIAWIKI)\
      .analyze
  end

  def analyze_links_hiki(source)
    Hiki2MW::LinkAnalyzer.new(source, Hiki2MW::LinkAnalyzer::MODE_HIKI)\
      .analyze
  end
end
