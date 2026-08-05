import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import java.io.File;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

/**
 * Tiny web app for the "Why Docker" UI practical.
 * Serves one page that prints the ACTUAL Java runtime executing it.
 * Kept Java 8 source-compatible so the SAME file runs under any JVM.
 *
 * Port comes from the PORT env var (default 8080).
 */
public class Server {

    public static void main(String[] args) throws Exception {
        String portEnv = System.getenv("PORT");
        int port = (portEnv != null && !portEnv.isEmpty()) ? Integer.parseInt(portEnv) : 8080;

        final String javaVersion = System.getProperty("java.version");
        final String vendor      = System.getProperty("java.vendor");
        final boolean inDocker   = new File("/.dockerenv").exists();

        String major;
        if (javaVersion.startsWith("1.")) {
            major = javaVersion.split("\\.")[1];   // "1.8.0_402" -> "8"
        } else {
            major = javaVersion.split("\\.")[0];   // "17.0.10"   -> "17"
        }

        final String majorF = major;
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        final int portF = port;

        server.createContext("/", new HttpHandler() {
            public void handle(HttpExchange ex) throws java.io.IOException {
                String html = page(majorF, javaVersion, vendor, inDocker, portF);
                byte[] body = html.getBytes(StandardCharsets.UTF_8);
                ex.getResponseHeaders().add("Content-Type", "text/html; charset=utf-8");
                ex.sendResponseHeaders(200, body.length);
                OutputStream os = ex.getResponseBody();
                os.write(body);
                os.close();
            }
        });

        server.setExecutor(null);
        server.start();
        System.out.println("[Server] Up on port " + port
                + " | Java " + javaVersion
                + " | " + (inDocker ? "inside Docker container" : "on host VM"));
    }

    static String page(String major, String full, String vendor, boolean inDocker, int port) {
        String accent = major.equals("8") ? "#f0a742" : "#3fd0dc";  // 8=amber, others=cyan
        String where  = inDocker ? "Inside a Docker container" : "On the host VM";
        return "<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'>"
            + "<meta name='viewport' content='width=device-width,initial-scale=1'>"
            + "<meta http-equiv='refresh' content='5'>"   // auto-refresh so a switch is visible
            + "<title>Java " + major + " app</title>"
            + "<style>"
            + "*{box-sizing:border-box;margin:0;padding:0}"
            + "body{min-height:100vh;display:flex;align-items:center;justify-content:center;"
            + "font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;"
            + "background:#0a1622;color:#dce8f2;"
            + "background-image:linear-gradient(rgba(120,180,220,.10) 1px,transparent 1px),"
            + "linear-gradient(90deg,rgba(120,180,220,.10) 1px,transparent 1px);"
            + "background-size:32px 32px}"
            + ".card{border:1px solid " + accent + "55;border-radius:18px;padding:44px 52px;"
            + "background:rgba(14,30,47,.85);text-align:center;box-shadow:0 20px 60px rgba(0,0,0,.4)}"
            + ".tag{font:600 12px/1 'JetBrains Mono',monospace;letter-spacing:.22em;text-transform:uppercase;"
            + "color:" + accent + ";display:inline-block;margin-bottom:18px}"
            + ".big{font-size:clamp(3rem,12vw,6rem);font-weight:800;line-height:1;letter-spacing:-.03em;"
            + "color:" + accent + "}"
            + ".big small{display:block;font-size:1rem;font-weight:600;color:#8499ab;letter-spacing:.1em;"
            + "text-transform:uppercase;margin-bottom:10px}"
            + ".full{font:500 15px/1.5 'JetBrains Mono',monospace;color:#dce8f2;margin-top:22px}"
            + ".meta{font:400 13px/1.6 'JetBrains Mono',monospace;color:#8499ab;margin-top:14px}"
            + ".pill{display:inline-block;margin-top:20px;padding:7px 16px;border-radius:30px;"
            + "border:1px solid " + accent + "55;color:" + accent + ";"
            + "font:600 12px/1 'JetBrains Mono',monospace;letter-spacing:.08em}"
            + "</style></head><body><div class='card'>"
            + "<span class='tag'>Live runtime report</span>"
            + "<div class='big'><small>Running with</small>Java " + major + "</div>"
            + "<div class='full'>java.version = " + full + "</div>"
            + "<div class='meta'>" + vendor + " &nbsp;&middot;&nbsp; port " + port + "</div>"
            + "<div class='pill'>" + where + "</div>"
            + "</div></body></html>";
    }
}
