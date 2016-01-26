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

    pack_rexp = /\\ref{.*?}|\\footnote{.*?}|\\begin{figure}.*?\\end{figure}/m
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
        # next if plus_str.gsub(pack_mark(pack_identifier),"").gsub("\n" ,'') # 図表のみの時とか．改良が必要
        cdiff = Diff::LCS.diff(minus_str, plus_str)
        cdiff.each do |cseq|
            cplus = cseq.select{|c| c.action == "+"}
            if cplus.length > 0
                cplus_pos = cplus.map(&:position)
                cplus_str = cplus.map(&:element).join
                tag_counter = 0
                marked_str = cplus_str.split(pack_mark(pack_identifier)).map{ |s|
                    next if s.split.join == '' # 改行と空白のみの者は除外
                    tag_counter += 1
                    before_tag + s + after_tag
                }.join(pack_mark(pack_identifier)) # 保護文字列は改変しないようにする．
                plus_str[(cbias+cplus_pos.first)...(cbias+cplus_pos.last+1)] = marked_str
                # plus_str.insert cbias + cplus_pos.last + 1, after_tag
                # plus_str.insert cbias + cplus_pos.first, before_tag
                cbias += (before_tag.length + after_tag.length) * tag_counter
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
