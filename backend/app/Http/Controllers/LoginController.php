<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class LoginController extends Controller
{
    public function form(Request $request)
    {
        return $request->session()->get('painel_ok') ? redirect()->route('painel') : view('auth.login');
    }

    public function entrar(Request $request)
    {
        $d = $request->validate([
            'usuario' => 'required|string',
            'senha' => 'required|string',
        ], [
            'usuario.required' => 'Informe o usuário.',
            'senha.required' => 'Informe a senha.',
        ]);

        $user = (string) config('jotalle.painel_user');
        $pass = (string) config('jotalle.painel_password');

        if ($user === '' || $pass === '') {
            return back()->withErrors(['usuario' => 'Painel sem usuário/senha configurados no servidor (.env).']);
        }

        // compara os dois sempre, para não revelar qual está errado
        $okUser = hash_equals($user, $d['usuario']);
        $okPass = hash_equals($pass, $d['senha']);

        if (! ($okUser && $okPass)) {
            return back()->withInput($request->only('usuario'))
                ->withErrors(['usuario' => 'Usuário ou senha incorretos.']);
        }

        $request->session()->regenerate();
        $request->session()->put('painel_ok', true);
        $request->session()->put('painel_nome', $user);

        return redirect($request->session()->pull('url.intended', route('painel')));
    }

    public function sair(Request $request)
    {
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
