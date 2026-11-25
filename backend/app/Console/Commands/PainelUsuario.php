<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class PainelUsuario extends Command
{
    protected $signature = 'painel:usuario {nome} {email} {senha?}';

    protected $description = 'Cria ou atualiza um usuário do painel (pede a senha se não for informada)';

    public function handle(): int
    {
        $senha = $this->argument('senha') ?: $this->secret('Senha');

        if (strlen((string) $senha) < 8) {
            $this->error('A senha precisa ter pelo menos 8 caracteres.');

            return self::FAILURE;
        }

        User::updateOrCreate(
            ['email' => $this->argument('email')],
            ['name' => $this->argument('nome'), 'password' => Hash::make($senha)]
        );

        $this->info('Usuário salvo: '.$this->argument('email'));

        return self::SUCCESS;
    }
}
