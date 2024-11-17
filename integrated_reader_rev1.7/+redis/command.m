function out = command(conn, bytearr)

conn.output_stream.write(bytearr);

timeout = 0.5;
tic
while conn.input_stream.available == 0
  pause(0.001)
  if toc >= timeout
    out = 'ERROR - REDIS TIMEOUT';
    return;
  end
end

out = {};
while conn.input_stream.available > 0
    line = conn.reader.readLine();
    out = [out; char(line)];
%     out = [out, char(line), '\r\n'];
end

return;

% wait for bytes to show up
timeout = 1.0;
tic
while conn.input_stream.available == 0
  pause(0.005)
  if toc >= timeout
    out = 'ERROR - REDIS TIMEOUT';
    return;
  end
end

response = '';
tic
while conn.input_stream.available > 0
%   buff = javaArray('java.lang.Byte', conn.input_stream.available);
  
  try
    chunk = conn.input_stream.read();
  catch E
    fprintf('Caught this: %s\n', getReport(E));
    break;
  end
  response = [response chunk];
end

out = char(response);
S = 'OK';
