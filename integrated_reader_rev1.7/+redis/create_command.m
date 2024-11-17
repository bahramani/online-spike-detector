function [bytearr, payload_ind] = create_command(redis_cmd, binary_payload)

cmd = strtrim(redis_cmd);
words = regexp(cmd, '\s', 'split');

n_words = numel(words);

if nargin > 1
    cmd = sprintf('*%d', n_words + 1);
    for ix = 1 : n_words
        word = words{ix};
        word_length = numel(word);
        cmd = sprintf('%s\r\n$%d\r\n%s', cmd, word_length, word);
    end

    cmd = sprintf('%s\r\n$%d\r\n', cmd, length(binary_payload));    
    bytearr = uint8(cmd);
    payload_ind = (length(bytearr) + 1):...
                  (length(bytearr) + length(binary_payload));
    bytearr = [bytearr, binary_payload, 13, 10];
else
    cmd = sprintf('*%d', n_words);
    for ix = 1 : n_words
        word = words{ix};
        word_length = numel(word);
        cmd = sprintf('%s\r\n$%d\r\n%s', cmd, word_length, word);
    end
    cmd = [cmd, sprintf('\r\n')];
    bytearr = uint8(cmd);
    payload_ind= [];
end
