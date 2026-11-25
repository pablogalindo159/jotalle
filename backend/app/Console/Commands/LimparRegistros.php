<?php

namespace App\Console\Commands;

use App\Models\Registro;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class LimparRegistros extends Command
{
    protected $signature = 'registros:limpar {--dias= : Apaga registros mais antigos que N dias (padrão: RETENCAO_APAGAR_DIAS, 35)} {--simular : Só mostra quantos seriam apagados}';

    protected $description = 'Apaga fotos/PDFs e registros mais antigos que o prazo de retenção';

    public function handle(): int
    {
        $dias = (int) ($this->option('dias') ?: config('jotalle.apagar_dias'));
        if ($dias < 1) {
            $this->error('Prazo inválido.');

            return self::FAILURE;
        }

        $limite = now()->subDays($dias);
        $q = Registro::where('tirado_em', '<', $limite);
        $total = (clone $q)->count();

        if ($this->option('simular')) {
            $this->info("$total registro(s) com mais de $dias dia(s) seriam apagados (antes de {$limite->format('d/m/Y H:i')}).");

            return self::SUCCESS;
        }

        $apagados = 0;
        $q->orderBy('id')->chunkById(200, function ($lote) use (&$apagados) {
            foreach ($lote as $r) {
                Storage::disk('local')->delete($r->arquivo);
                $r->delete();
                $apagados++;
            }
        });

        $this->info("$apagados registro(s) com mais de $dias dia(s) apagados.");

        return self::SUCCESS;
    }
}
