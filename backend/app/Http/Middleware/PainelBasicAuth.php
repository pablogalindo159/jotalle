<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/** Protege o painel com usuário/senha do .env (PAINEL_USER / PAINEL_PASSWORD). */
class PainelBasicAuth
{
    public function handle(Request $request, Closure $next)
    {
        $user = config('jotalle.painel_user');
        $pass = config('jotalle.painel_password');

        if (! $user || ! $pass) {
            abort(503, 'Defina PAINEL_USER e PAINEL_PASSWORD no .env.');
        }

        if (! hash_equals($user, (string) $request->getUser()) || ! hash_equals($pass, (string) $request->getPassword())) {
            return response('Acesso restrito.', 401, ['WWW-Authenticate' => 'Basic realm="Jotalle"']);
        }

        return $next($request);
    }
}
