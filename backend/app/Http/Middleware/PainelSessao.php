<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/** Exige login do painel (usuário/senha do .env), guardado na sessão. */
class PainelSessao
{
    public function handle(Request $request, Closure $next)
    {
        if (! $request->session()->get('painel_ok')) {
            $request->session()->put('url.intended', $request->fullUrl());

            return redirect()->route('login');
        }

        return $next($request);
    }
}
