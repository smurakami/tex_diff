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

def mark_text(text, before_tag, after_tag, packed_str)
    text.split(packed_str).map{ |s|
        next s if s.split.join == '' # 改行と空白のみの者は除外
        s.split("\n").map { |s_| # 改行ごとに色つけをする
            if s_ == ''
                s_
            else
                before_tag + s_ + after_tag
            end
        }.join("\n")
    }.join(packed_str) # 保護文字列は改変しないようにする．
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

    # 保護する文字列パターン
    pack_rexp = Regexp.new([
        '\\\\ref{.*?}',
        '\\\\footnote{.*?}',
        '\\\\begin{figure}.*?\\\\end{figure}',
        '\\\\begin{thebibliography}({.*?})?',
        '\\\\end{thebibliography}',
        '\\\\section\*?{.*?}',
        '\\\\renewcommand{.*?}{.*?}',
        '\\\\newpage',
        ].join('|'), Regexp::MULTILINE)

    p pack_rexp
    p pack_rexp_ = /\\ref{.*?}|\\footnote{.*?}|\\begin{figure}.*?\\end{figure}|\\section\*?{.*?}/m
    pack_identifier = 'command'
    prev_body, prev_command_buf = pack 'command', prev_body, pack_rexp
    current_body, current_command_buf = pack 'command', current_body, pack_rexp

    current_body = current_body.split("\n")
    prev_body = prev_body.split("\n")

    before_tag = '\\textcolor{blue}{'
    after_tag = '}'

    diff = Diff::LCS.diff(prev_body, current_body)
    bias = 0

    diff.each do |seq|
        cbias = 0
        minus = seq.select{|d| d.action == '-'}
        plus  = seq.select{|d| d.action == '+'}
        next if plus.length == 0

        minus_str = minus.map(&:element).join("\n")
        plus_str = plus.map(&:element).join("\n")
        plus_pos = seq.select{|d| d.action == '+'}.map(&:position)
        cdiff = Diff::LCS.diff(minus_str, plus_str)
        cdiff.each do |cseq|
            cplus = cseq.select{|c| c.action == "+"}
            if cplus.length > 0
                cplus_pos = cplus.map(&:position)
                cplus_str = cplus.map(&:element).join

                marked_str = mark_text(cplus_str, before_tag, after_tag, pack_mark(pack_identifier))

                plus_str[(cbias+cplus_pos.first)...(cbias+cplus_pos.last+1)] = marked_str
                cbias += marked_str.length - cplus_str.length
            end
        end
        plus_str = plus_str.split("\n")
        current_body[(plus_pos.first+bias)..(plus_pos.last+bias)] = plus_str
        bias += plus_str.length - plus.length
    end

    current_body = current_body.join("\n")

    current_body = unpack 'command', current_body, current_command_buf

    result = current.sub(/\\begin{document}.*\\end{document}/m) { current_body }
    File.open(outfilename, 'w').write(result)
end

main
