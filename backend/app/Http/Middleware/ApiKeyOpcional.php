<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/** Se APP_API_KEY estiver definida no .env, exige o header X-Api-Key. Vazia = API aberta. */
class ApiKeyOpcional
{
    public function handle(Request $request, Closure $next)
    {
        $key = config('jotalle.api_key');

        if ($key && ! hash_equals($key, (string) $request->header('X-Api-Key'))) {
            return response()->json(['message' => 'Chave de API inválida.'], 401);
        }

        return $next($request);
    }
}
