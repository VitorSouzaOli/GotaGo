import { createHash } from "node:crypto";

const script = `
const form = document.querySelector("form");
const message = document.querySelector("[role=status]");
const token = new URLSearchParams(location.hash.slice(1)).get("token");
if (!token) { message.textContent = "Link incompleto. Peça um novo no aplicativo."; form.hidden = true; }
form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const { password, confirmation } = form.elements;
  if (password.value !== confirmation.value) { message.textContent = "As senhas não coincidem."; return; }
  const response = await fetch(location.pathname, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ token, password: password.value }),
  }).catch(() => null);
  if (response && response.ok) {
    form.hidden = true;
    message.textContent = "Senha atualizada! Volte ao aplicativo e entre com a nova senha.";
    return;
  }
  const data = response ? await response.json().catch(() => ({})) : {};
  message.textContent = data.error === "Dados inválidos."
    ? "A senha precisa ter de 6 a 72 caracteres."
    : data.error || "Não foi possível salvar. Tente novamente.";
});
`;

const style = `
body { font-family: system-ui, sans-serif; max-width: 22rem; margin: 3rem auto; padding: 0 1rem; background: #fff; color: #0b3b3c; }
label { display: block; margin-bottom: 1rem; }
input, button { box-sizing: border-box; width: 100%; padding: .75rem; margin-top: .25rem; font: inherit; }
button { background: #0b3b3c; color: #fff; border: 0; border-radius: .5rem; }
`;

const sha256 = (content: string) =>
  `'sha256-${createHash("sha256").update(content).digest("base64")}'`;

export const resetPasswordPageHeaders = {
  "content-type": "text/html; charset=utf-8",
  "cache-control": "no-store",
  "referrer-policy": "no-referrer",
  // Só o script e o estilo desta página podem rodar
  "content-security-policy": `default-src 'none'; connect-src 'self'; script-src ${sha256(script)}; style-src ${sha256(style)}; frame-ancestors 'none'; form-action 'none'; base-uri 'none'`,
};

export const resetPasswordPage = `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>GotaGo - Nova senha</title>
<style>${style}</style>
</head>
<body>
<h1>Crie uma nova senha</h1>
<form>
<label>Nova senha<input type="password" name="password" minlength="6" maxlength="72" autocomplete="new-password" required></label>
<label>Confirmar nova senha<input type="password" name="confirmation" minlength="6" maxlength="72" autocomplete="new-password" required></label>
<button>Salvar nova senha</button>
</form>
<p role="status"></p>
<script>${script}</script>
</body>
</html>`;
