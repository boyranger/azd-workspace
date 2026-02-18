use std::env;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::process::ExitCode;

fn main() -> ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();

    if args.is_empty() || args[0] != "gateway" {
        eprintln!("{}", usage());
        return ExitCode::from(2);
    }

    let host = parse_flag_value(&args, "--host").unwrap_or_else(|| "127.0.0.1".to_string());
    let port = parse_port(&args).unwrap_or(8080);
    let addr = format!("{host}:{port}");

    let listener = match TcpListener::bind(&addr) {
        Ok(listener) => listener,
        Err(err) => {
            eprintln!("failed to bind {addr}: {err}");
            return ExitCode::from(1);
        }
    };

    eprintln!("zeroclaw gateway listening on http://{addr}");

    for incoming in listener.incoming() {
        match incoming {
            Ok(mut stream) => {
                if let Err(err) = handle_connection(&mut stream) {
                    eprintln!("request error: {err}");
                }
            }
            Err(err) => eprintln!("accept error: {err}"),
        }
    }

    ExitCode::SUCCESS
}

fn parse_port(args: &[String]) -> Option<u16> {
    let from_arg = parse_flag_value(args, "--port").and_then(|v| v.parse::<u16>().ok());
    if from_arg.is_some() {
        return from_arg;
    }

    env::var("PORT").ok()?.parse::<u16>().ok()
}

fn parse_flag_value(args: &[String], name: &str) -> Option<String> {
    args.windows(2)
        .find(|pair| pair[0] == name)
        .map(|pair| pair[1].clone())
}

fn handle_connection(stream: &mut TcpStream) -> std::io::Result<()> {
    let mut buf = [0u8; 8192];
    let size = stream.read(&mut buf)?;
    if size == 0 {
        return Ok(());
    }

    let request = String::from_utf8_lossy(&buf[..size]);
    let mut lines = request.lines();
    let request_line = lines.next().unwrap_or_default();
    let path = request_line.split_whitespace().nth(1).unwrap_or("/");

    let database_url = env::var("DATABASE_URL").unwrap_or_else(|_| "unset".to_string());
    let (status, content_type, body) = match path {
        "/health" | "/ready" => ("200 OK", "text/plain; charset=utf-8", "ok\n".to_string()),
        "/" => (
            "200 OK",
            "application/json; charset=utf-8",
            format!(
                "{{\"service\":\"zeroclaw\",\"status\":\"ok\",\"database_url\":\"{}\"}}\n",
                escape_json(&database_url)
            ),
        ),
        _ => (
            "404 Not Found",
            "application/json; charset=utf-8",
            "{\"error\":\"not found\"}\n".to_string(),
        ),
    };

    let response = format!(
        "HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    stream.write_all(response.as_bytes())?;
    stream.flush()?;
    Ok(())
}

fn escape_json(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for c in input.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            _ => out.push(c),
        }
    }
    out
}

fn usage() -> &'static str {
    "Usage: zeroclaw gateway [--host <ip>] [--port <port>]\n\
     Example: zeroclaw gateway --host 0.0.0.0 --port 8080"
}
