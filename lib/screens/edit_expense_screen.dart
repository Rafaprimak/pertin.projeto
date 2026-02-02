import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/models/trip.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/widgets/common_widgets.dart';
import 'package:pertin/theme/app_colors.dart';

class EditExpenseScreen extends StatefulWidget {
  final String tripId;
  final String expenseId;

  const EditExpenseScreen({
    super.key, 
    required this.tripId, 
    required this.expenseId,
  });

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.passagem;
  bool _isLoading = false;
  TripExpense? _expense;

  @override
  void initState() {
    super.initState();
    _loadExpense();
  }

  void _loadExpense() {
    final tripProvider = context.read<TripProvider>();
    _expense = tripProvider.getExpenseById(widget.tripId, widget.expenseId);
    
    if (_expense != null) {
      _descriptionController.text = _expense!.description;
      _amountController.text = _expense!.amount.toStringAsFixed(2).replaceAll('.', ',');
      _selectedCategory = _expense!.category;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final amount = double.tryParse(
      _amountController.text.replaceAll(',', '.'),
    );

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um valor válido'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    final success = await context.read<TripProvider>().updateExpense(
      tripId: widget.tripId,
      expenseId: widget.expenseId,
      description: _descriptionController.text.trim(),
      amount: amount,
      category: _selectedCategory,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto atualizado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar gasto'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _deleteExpense() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Excluir Gasto',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Tem certeza que deseja excluir este gasto? Esta ação não pode ser desfeita.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.midnightBlue,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<TripProvider>().deleteExpense(
        widget.tripId,
        widget.expenseId,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto excluído'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_expense == null) {
      return Scaffold(
        body: StarrySkyBackground(
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gasto não encontrado',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    text: 'Voltar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: StarrySkyBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAmountCard(),
                        const SizedBox(height: 20),
                        _buildDescriptionCard(),
                        const SizedBox(height: 20),
                        _buildCategoryCard(),
                        const SizedBox(height: 32),
                        GradientButton(
                          text: 'Salvar Alterações',
                          icon: Icons.save,
                          isLoading: _isLoading,
                          onPressed: _updateExpense,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _deleteExpense,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Excluir Gasto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: AppColors.midnightBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
          ),
          const Expanded(
            child: Text(
              'Editar Gasto',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.starYellow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: AppColors.starYellow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Valor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.starYellow,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0,00',
              hintStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted.withOpacity(0.5),
              ),
              prefixText: 'R\$ ',
              prefixStyle: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.starYellow,
              ),
              border: InputBorder.none,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Digite o valor';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return GlassCard(
      child: StyledTextField(
        controller: _descriptionController,
        labelText: 'Descrição',
        hintText: 'Ex: Passagem de ônibus',
        prefixIcon: Icons.description,
        maxLines: 2,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Digite uma descrição';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCategoryCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.babyBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.category,
                  color: AppColors.babyBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Categoria',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ExpenseCategory.values.map((category) {
              final isSelected = _selectedCategory == category;

              return InkWell(
                onTap: () {
                  setState(() => _selectedCategory = category);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.babyBlue.withOpacity(0.2)
                        : AppColors.surfaceDark.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.babyBlue
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category.displayName,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.babyBlue
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
