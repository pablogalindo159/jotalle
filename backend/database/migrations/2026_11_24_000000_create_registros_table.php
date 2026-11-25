<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('registros', function (Blueprint $t) {
            $t->id();
            $t->uuid('device_uuid')->unique();      // idempotência da fila offline do app
            $t->string('tipo', 12)->index();         // foto | documento
            $t->string('placa_cavalo', 10)->nullable()->index();
            $t->string('placa_carreta', 10)->nullable()->index();
            $t->dateTime('tirado_em')->index();
            $t->string('rua')->nullable();
            $t->string('bairro')->nullable();
            $t->string('cidade')->nullable();
            $t->string('estado', 40)->nullable();
            $t->text('endereco')->nullable();
            $t->decimal('latitude', 10, 7)->nullable();
            $t->decimal('longitude', 10, 7)->nullable();
            $t->string('arquivo');                   // caminho no disco 'local'
            $t->string('mime', 40)->nullable();
            $t->unsignedBigInteger('tamanho')->default(0);
            $t->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('registros');
    }
};
