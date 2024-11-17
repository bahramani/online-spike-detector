function [secs, micros] = time(conn)

bytearr = redis.create_command('TIME');
out = redis.command(conn, bytearr);
secs = out{3};
micros = out{5};