import "@fastify/jwt";

// Diz ao TypeScript o que existe dentro do token JWT:
// "sub" (subject) guarda o ID do usuário dono do token.
declare module "@fastify/jwt" {
  interface FastifyJWT {
    payload: { sub: string };
    user: { sub: string };
  }
}
