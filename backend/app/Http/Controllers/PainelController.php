<?php

namespace App\Http\Controllers;

use App\Models\Registro;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class PainelController extends Controller
{
    public function index(Request $request)
    {
        $q = Registro::query()->latest('tirado_em');
        $desde = now()->subDays(config('jotalle.exibir_dias'))->startOfDay();
        $q->where('tirado_em', '>=', $desde);

        if ($busca = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', (string) $request->query('placa')))) {
            $q->where(fn ($w) => $w->where('placa_cavalo', 'like', "%$busca%")
                ->orWhere('placa_carreta', 'like', "%$busca%"));
        }
        if ($request->filled('motorista')) {
            $q->where('motorista', 'like', '%'.trim($request->query('motorista')).'%');
        }
        if (in_array($request->query('tipo'), ['foto', 'documento'], true)) {
            $q->where('tipo', $request->query('tipo'));
        }
        if ($request->filled('de')) {
            $q->whereDate('tirado_em', '>=', $request->query('de'));
        }
        if ($request->filled('ate')) {
            $q->whereDate('tirado_em', '<=', $request->query('ate'));
        }
        if ($request->filled('cidade')) {
            $q->where('cidade', 'like', '%'.$request->query('cidade').'%');
        }

        return view('painel.index', [
            'exibirDias' => config('jotalle.exibir_dias'),
            'registros' => $q->paginate(24)->withQueryString(),
        ]);
    }

    /** Exibe o arquivo no navegador (miniaturas / visualização). */
    public function arquivo(Registro $registro)
    {
        abort_unless(Storage::disk('local')->exists($registro->arquivo), 404);

        return Storage::disk('local')->response($registro->arquivo, $registro->nome_download, [
            'Content-Type' => $registro->mime ?: 'application/octet-stream',
        ]);
    }

    public function download(Registro $registro)
    {
        abort_unless(Storage::disk('local')->exists($registro->arquivo), 404);

        return Storage::disk('local')->download($registro->arquivo, $registro->nome_download);
    }

    /** Exclui o registro e o arquivo do disco. */
    public function excluir(Registro $registro)
    {
        Storage::disk('local')->delete($registro->arquivo);
        $registro->delete();

        return back()->with('ok', 'Registro excluído.');
    }
}
