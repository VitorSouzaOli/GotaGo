import "@fastify/jwt";

declare module "@fastify/jwt" {
  interface FastifyJWT {
    payload: { sub: string }; // ID do utilizador guardado no token
    user: {
      sub: string;
    };
  }
}
