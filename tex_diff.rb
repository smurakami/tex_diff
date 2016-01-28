require "diff/lcs"

def pack_mark(identifier)
  "[++#{identifier}++]"
end

def pack(identifier, input, rexp)
  buffer = []

  output = input.gsub(rexp) do |pattern|
    buffer.push pattern
    pack_mark(identifier)
  end
  [output, buffer]
end

def unpack(identifier, input, buffer)
  index = 0
  output = input.gsub(/\[\+\+#{identifier}\+\+\]/) do |pattern|
    index_ = index
    index += 1
    buffer[index_]
  end
  output
end

def diff_elements_to_char_array(elements, packed_s)
  elements_keeper = Consts::ELEMENTS_KEEPER
  packed_keeper = 'IrNa/5X1hm7Xj45d'
  char_array = elements.map do |s|
    (s + packed_keeper)
      .split(packed_s)
      .map{|s| s.gsub(packed_keeper, '')}
      .map{|s| s.split('')}
      .reduce{|a, b| a + [packed_s] + b}
  end
  char_array.reduce{|a, b| a + [elements_keeper] + b} || ""
end

def char_array_to_diff_elements(char_array)
  elements_keeper = Consts::ELEMENTS_KEEPER
  char_array = char_array.join.split(elements_keeper)
end

module Consts
  K_OPEN_DOLLER_2 = "sMaNflJP4pTOM45x" # $$
  K_CLOSE_DOLLER_2 = "IUO7zvzeIq38xB3E" # $$
  K_OPEN_DOLLER = "dZwRCFunwL7CpkXx" # $
  K_CLOSE_DOLLER = "YHCXwuT87dVzHyqN" # $
  EQUATION_OPEN_PATTERNS = [
    K_OPEN_DOLLER,
    K_OPEN_DOLLER_2,
    "\\[",
    "\\\\begin{equation}",
  ]
  EQUATION_CLOSE_PATTERNS = [
    K_CLOSE_DOLLER,
    K_CLOSE_DOLLER_2,
    "\\]",
    "\\\\end{equation}"
  ]
  ELEMENTS_KEEPER = '4o+jfNB0jMhXSO1L'
end

def is_equation(text)
  s = text.split.join
  Consts::EQUATION_OPEN_PATTERNS.zip(Consts::EQUATION_CLOSE_PATTERNS).each do |open, close|
    return true if s.match(/^#{open}.*#{close}/)
  end
  false
end

def is_figure(text)
  s = text.split.join
  !!s.match(/^\\begin{figure}.*\\end{figure}$/)
end

def encode_doller(text)
  flag = true
  text = text.gsub("$$") do
    flag_ = flag
    flag = !flag
    if flag_
      Consts::K_OPEN_DOLLER_2
    else
      Consts::K_CLOSE_DOLLER_2
    end
  end
  flag = true
  text = text.gsub("$") do
    flag_ = flag
    flag = !flag
    if flag_
      Consts::K_OPEN_DOLLER
    else
      Consts::K_CLOSE_DOLLER
    end
  end
  text
end

def decode_doller(text)
  text = text.gsub(/#{Consts::K_OPEN_DOLLER_2}|#{Consts::K_CLOSE_DOLLER_2}/) { "$$" }
  text = text.gsub(/#{Consts::K_OPEN_DOLLER}|#{Consts::K_CLOSE_DOLLER}/) { "$" }
  text
end

# 差分領域を青色に
def mark_text(text, before_tag, after_tag, packed_str)
  keeper = 'a5cQCDV5zP'
  (text + keeper).split(packed_str).map{ |s|
    next s if s.gsub(Consts::ELEMENTS_KEEPER, '').split.join == '' # 改行と空白のみの者は除外

    s.lines.map { |s_| # 改行ごとに色つけをする
      if s_.split.join.gsub(Consts::ELEMENTS_KEEPER, '') == ''
        s_
      else
        before_tag + s_.gsub("\n", '') + after_tag + "\n"
      end
    }.join
  }.join(packed_str).gsub(keeper, '') # 保護文字列は改変しないようにする．
end

def main
  if ARGV.length < 2
    puts "Usage: ruby create_diff.rb filename branchname [outfilename]"
    return
  end
  filename = ARGV[0]
  branchname = ARGV[1]
  outfilename = ARGV[2] || "diff.tex"

  prev = `git cat-file -p #{branchname}:#{filename}`
  current = File.open(filename).read

  prev_body = prev.match(/\\begin{document}.*\\end{document}/m)[0]
  current_body = current.match(/\\begin{document}.*\\end{document}/m)[0]

  prev_body = encode_doller(prev_body)
  current_body = encode_doller(current_body)

  # 保護する文字列パターン
  pack_rexp = Regexp.new(([
    '\\\\ref{.*?}',
    '%.*?\\n',
    '\\\\cite{.*?}',
    '\\\\label{.*?}',
    '\\\\footnote{.*?}',
    '\\\\begin{figure}.*?\\\\end{figure}',
    '\\\\begin{table}.*?\\\\end{table}',
    '\\\\begin{thebibliography}({.*?})?',
    '\\\\end{thebibliography}',
    '\\\\(sub)*section\*?{.*?}',
    '\\\\renewcommand{.*?}{.*?}',
    '\\\\newpage',
    '\\\\listoffigures',
    '\\\\listoftables',
    ] + Consts::EQUATION_OPEN_PATTERNS.zip(Consts::EQUATION_CLOSE_PATTERNS).map{ |open, close|
      "#{open}.*?#{close}"
    }).join('|'), Regexp::MULTILINE)


  pack_identifier = 'command'
  prev_body, prev_packed_buf = pack 'command', prev_body, pack_rexp
  current_body, current_packed_buf = pack 'command', current_body, pack_rexp

  current_body = current_body.lines
  prev_body = prev_body.lines

  before_tag = '\\textcolor{blue}{'
  after_tag = '}'

  diff = Diff::LCS.diff(prev_body, current_body)
  bias = 0

  diff.each do |seq|
    cbias = 0
    minus = seq.select{|d| d.action == '-'}
    plus  = seq.select{|d| d.action == '+'}
    next if plus.length == 0

    plus_str  = diff_elements_to_char_array(plus.map(&:element), pack_mark(pack_identifier))
    minus_str = diff_elements_to_char_array(minus.map(&:element), pack_mark(pack_identifier))

    plus_pos = seq.select{|d| d.action == '+'}.map(&:position)
    cdiff = Diff::LCS.diff(minus_str, plus_str)
    cdiff.each do |cseq|
      cplus = cseq.select{|c| c.action == "+"}
      if cplus.length > 0
        cplus_pos = cplus.map(&:position)
        cplus_str = cplus.map(&:element)

        marked_str = mark_text(cplus_str.join, before_tag, after_tag, pack_mark(pack_identifier))
        plus_str[(cbias+cplus_pos.first)...(cbias+cplus_pos.last+1)] = marked_str.split('')
        cbias += marked_str.length - cplus_str.length
      end
    end

    plus_str = char_array_to_diff_elements(plus_str)

    current_body[(plus_pos.first+bias)..(plus_pos.last+bias)] = plus_str
    bias += plus_str.length - plus.length
  end

  # 数式などの処理
  diff = Diff::LCS.diff(prev_packed_buf, current_packed_buf)
  diff.each do |seq|
    plus = seq.select{|d| d.action == '+'}
    plus.each do |d|
      if is_equation(d.element)
        eq_begin_re = Regexp.new("^(#{Consts::EQUATION_OPEN_PATTERNS.join('|')})")
        s = d.element.gsub(eq_begin_re) { $1 + "\\color{blue}" }
        current_packed_buf[d.position] = s
      end
      if is_figure(d.element)
        s = d.element.gsub(/(\\caption(\[.*?\])?\s*)(?<paren>{([^{}]|\g<paren>)*})/m) do |m|
          m.gsub(/(?<paren>{([^{}]|\g<paren>)*})/m) do |m_|
            "{\\textcolor{blue}" + m_ + "}"
          end
        end
        current_packed_buf[d.position] = s
      end
    end
  end

  current_body = current_body.join

  current_body = unpack 'command', current_body, current_packed_buf
  current_body = decode_doller(current_body)

  result = current.sub(/\\begin{document}.*\\end{document}/m) { current_body }
  File.open(outfilename, 'w').write(result)
end

main
