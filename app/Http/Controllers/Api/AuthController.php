<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AuthController extends Controller
{

    public function login(Request $request){

        $credentials = $request->validate([
            'email'     => 'required|email',
            'password'  => 'required|password'
        ]);

        if(!$token = Auth::guard('api')->attempt($credentials)){
            return response()->json([
                'message' => 'Credenciales incorrecta.',
            ], 401);
        }

        return response()->json([
            'Token creado' => $token
        ], 201);
    }

}
